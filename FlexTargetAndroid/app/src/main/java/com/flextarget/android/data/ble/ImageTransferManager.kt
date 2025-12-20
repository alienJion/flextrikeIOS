package com.flextarget.android.data.ble

import android.graphics.Bitmap
import android.util.Log
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/// Manages chunked image transfer over BLE with compression
class ImageTransferManager(
    private val bleManager: BLEManager
) {
    private val chunkSize: Int = 200  // Bytes per chunk (safe MTU)
    private val timeoutInterval: Long = 5000  // 5 seconds

    // Transfer state
    private var transferInProgress = false
    private var currentChunks: List<ByteArray> = emptyList()
    private var currentChunkIndex = 0
    private var transferCompletion: ((Boolean, String) -> Unit)? = null
    private var progressHandler: ((Int) -> Unit)? = null
    private var transferJob: Job? = null

    // Device management
    private var masterDeviceName: String = "ET02"  // Default fallback
    private var readyObserver: Any? = null
    private var readyTimer: Job? = null

    // Public method to set the master device name
    fun setMasterDeviceName(name: String) {
        masterDeviceName = name
    }

    // MARK: - Public Methods

    /// Transfer an image over BLE with automatic compression
    /// - Parameters:
    ///   - image: Bitmap to transfer
    ///   - imageName: Name identifier for the image
    ///   - compressionQuality: JPEG quality 0.0-1.0 (default 0.2)
    ///   - completion: (success, message)
    fun transferImage(
        image: Bitmap,
        imageName: String,
        compressionQuality: Float = 0.2f,
        progress: ((Int) -> Unit)? = null,
        completion: (Boolean, String) -> Unit
    ) {
        if (transferInProgress) {
            completion(false, "Transfer already in progress")
            return
        }

        if (!bleManager.isConnected) {
            completion(false, "BLE not connected")
            return
        }

        // Prepare and start the transfer
        prepareAndStartTransfer(image, imageName, compressionQuality, progress, completion)
    }

    fun cancelTransfer() {
        transferJob?.cancel()
        readyTimer?.cancel()
        transferInProgress = false
        currentChunks = emptyList()
        currentChunkIndex = 0
        transferCompletion = null
        progressHandler = null
        readyObserver = null
    }



    private fun prepareAndStartTransfer(
        image: Bitmap,
        imageName: String,
        compressionQuality: Float,
        progress: ((Int) -> Unit)?,
        completion: (Boolean, String) -> Unit
    ) {
        // Compress image to JPEG
        val compressedData = compressImage(image, compressionQuality)
        if (compressedData.isEmpty()) {
            completion(false, "Failed to compress image")
            return
        }

        Log.d("ImageTransfer", "Preparing image transfer: $imageName")
        Log.d("ImageTransfer", "Original size: ${compressedData.size} bytes")

        // Prepare chunks but do not start sending until the device ACKs readiness
        transferInProgress = true
        transferCompletion = completion
        progressHandler = progress
        currentChunkIndex = 0
        currentChunks = createChunks(compressedData, chunkSize)

        Log.d("ImageTransfer", "Compressed size: ${compressedData.size} bytes")
        Log.d("ImageTransfer", "Chunks: ${currentChunks.size} × $chunkSize bytes")
        Log.d("ImageTransfer", "Target device: $masterDeviceName")

        // Send a readiness command to the device and wait for an ACK
        sendReadyCommandAndAwaitAck(imageName, compressedData.size, currentChunks.size)
    }

    // MARK: - Ready handshake

    private fun sendReadyCommandAndAwaitAck(imageName: String, totalSize: Int, totalChunks: Int) {
        // Build minimal ready message (netlink_forward) — only command
        val escapedDest = org.json.JSONObject.quote(masterDeviceName)
        val jsonString = "{\"action\":\"netlink_forward\",\"content\":{\"command\":\"image_transfer_ready\"},\"dest\":$escapedDest}"

        // Register observer for incoming netlink forward messages
        bleManager.onNetlinkForwardReceived = { json ->
            // The ACK may appear at top-level or inside content
            var ackValue: String? = null
            val content = json["content"] as? Map<String, Any>
            if (content != null) {
                ackValue = content["ack"] as? String
            } else {
                ackValue = json["ack"] as? String
            }

            if (ackValue == "image_transfer_ready") {
                // ACK received — cancel timer & observer and start transfer
                readyTimer?.cancel()
                readyTimer = null
                bleManager.onNetlinkForwardReceived = null

                // Small delay to ensure target has finished handshake processing
                transferJob = CoroutineScope(Dispatchers.Main).launch {
                    delay(200)
                    sendTransferStart(imageName, totalSize, totalChunks)
                }
            }
        }

        // Send the ready command
        bleManager.writeJSON(jsonString)

        // Start guard timer: if no ACK within configured timeout, cancel transfer
        readyTimer = CoroutineScope(Dispatchers.Main).launch {
            delay(timeoutInterval)
            // Remove observer
            bleManager.onNetlinkForwardReceived = null
            readyTimer = null
            failTransfer("Target not ready to receive image")
        }
    }

    private fun sendTransferStart(imageName: String, totalSize: Int, totalChunks: Int) {
        val escapedImageName = org.json.JSONObject.quote(imageName)
        val escapedDest = org.json.JSONObject.quote(masterDeviceName)
        val jsonString = "{\"action\":\"netlink_forward\",\"content\":{\"chunk_size\":$chunkSize,\"command\":\"image_transfer_start\",\"image_name\":$escapedImageName,\"total_chunks\":$totalChunks,\"total_size\":$totalSize},\"dest\":$escapedDest}"
        bleManager.writeJSON(jsonString)

        // Wait for acknowledgment then start sending chunks
        transferJob = CoroutineScope(Dispatchers.Main).launch {
            delay(500)
            sendNextChunk()
        }
    }

    private fun sendNextChunk() {
        if (!transferInProgress) return

        if (currentChunkIndex >= currentChunks.size) {
            // All chunks sent, send end command
            sendTransferEnd()
            return
        }

        val chunk = currentChunks[currentChunkIndex]
        if (!sendChunk(chunk, currentChunkIndex)) {
            CoroutineScope(Dispatchers.Main).launch {
                failTransfer("Failed to send chunk $currentChunkIndex")
            }
            return
        }

        // Update progress
        val progress = ((currentChunkIndex + 1).toFloat() / currentChunks.size * 100).toInt()
        progressHandler?.invoke(progress)

        currentChunkIndex++

        // Send next chunk after a small delay
        transferJob = CoroutineScope(Dispatchers.Main).launch {
            delay(200)  // Increased delay to match iOS (was 50ms)
            sendNextChunk()
        }
    }

    // MARK: - Private Methods

    private fun compressImage(image: Bitmap, quality: Float): ByteArray {
        Log.d("ImageTransfer", "Compressing image: ${image.width}x${image.height}, quality: $quality")
        val outputStream = ByteArrayOutputStream()
        val success = image.compress(Bitmap.CompressFormat.JPEG, (quality * 100).toInt(), outputStream)
        val data = outputStream.toByteArray()
        Log.d("ImageTransfer", "Compression ${if (success) "successful" else "failed"}, output size: ${data.size} bytes")
        if (data.isNotEmpty()) {
            Log.d("ImageTransfer", "First 10 bytes: ${data.take(10).joinToString(", ") { "0x%02x".format(it) }}")
        }
        return if (success) data else byteArrayOf()
    }

    private fun createChunks(data: ByteArray, chunkSize: Int): List<ByteArray> {
        Log.d("ImageTransfer", "Creating chunks: ${data.size} bytes, chunkSize: $chunkSize")
        val chunks = mutableListOf<ByteArray>()
        var offset = 0

        while (offset < data.size) {
            val remaining = data.size - offset
            val currentChunkSize = minOf(chunkSize, remaining)
            val chunk = data.copyOfRange(offset, offset + currentChunkSize)
            chunks.add(chunk)
            Log.d("ImageTransfer", "Created chunk ${chunks.size - 1}: $currentChunkSize bytes")
            offset += currentChunkSize
        }
        
        Log.d("ImageTransfer", "Total chunks created: ${chunks.size}")
        return chunks
    }

    private fun sendCommand(command: ByteArray): Boolean {
        // This would need to be implemented based on your BLE protocol
        // For now, return true as placeholder
        Log.d("ImageTransfer", "Sending command: ${command.joinToString(", ") { "0x%02x".format(it) }}")
        return true
    }

    private fun sendChunk(chunk: ByteArray, index: Int): Boolean {
        Log.d("ImageTransfer", "Chunk $index: ${chunk.size} bytes, first 10 bytes: ${chunk.take(10).joinToString(", ") { "0x%02x".format(it) }}")
        
        val base64String = android.util.Base64.encodeToString(chunk, android.util.Base64.NO_WRAP)
        val escapedBase64 = org.json.JSONObject.quote(base64String)
        val escapedDest = org.json.JSONObject.quote(masterDeviceName)

        val jsonString = "{\"action\":\"netlink_forward\",\"content\":{\"command\":\"image_chunk\",\"chunk_index\":$index,\"data\":$escapedBase64},\"dest\":$escapedDest}"
        Log.d("ImageTransfer", "Sending chunk JSON: $jsonString")
        bleManager.writeJSON(jsonString)

        Log.d("ImageTransfer", "Sent chunk $index/${currentChunks.size} (${base64String.length} chars base64)")
        return true
    }

    private fun sendTransferEnd() {
        val escapedDest = org.json.JSONObject.quote(masterDeviceName)
        val jsonString = "{\"action\":\"netlink_forward\",\"content\":{\"command\":\"image_transfer_complete\",\"status\":\"success\"},\"dest\":$escapedDest}"
        bleManager.writeJSON(jsonString)

        // Success
        transferCompletion?.invoke(true, "Image transferred successfully")
        transferInProgress = false
    }

    private suspend fun failTransfer(message: String) {
        withContext(Dispatchers.Main) {
            transferCompletion?.invoke(false, message)
        }
        transferInProgress = false
    }
}