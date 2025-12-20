package com.flextarget.android.ui.ble

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.*
import com.flextarget.android.R
import com.flextarget.android.data.ble.BLEManager
import com.flextarget.android.data.ble.DiscoveredPeripheral
import com.flextarget.android.ui.imagecrop.ImageCropView
import kotlinx.coroutines.delay

@Composable
fun ConnectSmartTargetView(
    bleManager: BLEManager = BLEManager.shared,
    onDismiss: () -> Unit,
    targetPeripheralName: String? = null,
    isAlreadyConnected: Boolean = false,
    onConnected: (() -> Unit)? = null
) {
    var statusText by remember { mutableStateOf("CONNECTING") }
    var showReconnect by remember { mutableStateOf(false) }
    var showProgress by remember { mutableStateOf(false) }
    var showFirmwareAlert by remember { mutableStateOf(false) }
    var selectedPeripheral by remember { mutableStateOf<DiscoveredPeripheral?>(null) }
    var activeTargetName by remember { mutableStateOf<String?>(null) }
    var showImageCrop by remember { mutableStateOf(false) }

    // Animation states for sensor icons
    val infiniteTransition = rememberInfiniteTransition()
    val scaleAnimation = infiniteTransition.animateFloat(
        initialValue = 0.9f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    val opacityAnimation = infiniteTransition.animateFloat(
        initialValue = 0.6f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    fun goToMain() {
        onConnected?.invoke() ?: onDismiss()
    }

    fun handleReconnect() {
        statusText = "Trying to connect..."
        showReconnect = false
        selectedPeripheral = null
        bleManager.startScan()
        showProgress = true
    }

    fun connectToSelectedPeripheral(peripheral: DiscoveredPeripheral) {
        selectedPeripheral = peripheral
        statusText = "Trying to connect..."
        showProgress = true

        bleManager.connectToSelectedPeripheral(peripheral)
    }

    // Handle initial state
    LaunchedEffect(Unit) {
        if (isAlreadyConnected) {
            statusText = "Target Connected"
        } else {
            // If a target peripheral name was passed in, begin scanning
            if (targetPeripheralName != null) {
                activeTargetName = targetPeripheralName
                statusText = "Trying to connect..."
                showReconnect = false
                selectedPeripheral = null
                bleManager.startScan()
                showProgress = true
                statusText = "Scanning for $targetPeripheralName"
            } else {
                statusText = "Ready to scan"
                showProgress = false
            }
        }
    }

    var hasHandledInitialConnection by remember { mutableStateOf(false) }

    // Handle connection state changes
    LaunchedEffect(bleManager.isConnected) {
        if (bleManager.isConnected && !hasHandledInitialConnection) {
            hasHandledInitialConnection = true
            if (!isAlreadyConnected) {
                statusText = "Connected"
                showReconnect = false
                showProgress = false
                goToMain()
            }
        }
    }

    // Handle scanning logic
    LaunchedEffect(bleManager.isScanning, activeTargetName) {
        if (bleManager.isScanning && activeTargetName != null) {
            delay(2000) // 2 second delay to allow BLE to power on
            if (bleManager.isScanning) {
                val target = activeTargetName
                if (target != null) {
                    val match = bleManager.discoveredPeripherals.find { it.name == target }
                    if (match != null) {
                        bleManager.stopScan()
                        connectToSelectedPeripheral(match)
                    } else {
                        // Target not found
                        bleManager.stopScan()
                        statusText = "Target not found"
                        showReconnect = true
                        showProgress = false
                    }
                } else if (bleManager.discoveredPeripherals.isEmpty()) {
                    bleManager.stopScan()
                    statusText = "No targets found"
                    showReconnect = true
                    showProgress = false
                }
            }
        }
    }

    // Handle connection timeout
    LaunchedEffect(selectedPeripheral) {
        selectedPeripheral?.let { peripheral ->
            delay(10000)
            if (!bleManager.isConnected && selectedPeripheral == peripheral) {
                bleManager.disconnect()
                statusText = "Bluetooth service not found"
                showReconnect = true
                showProgress = false
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Visual Target Frame (matching iOS design)
            Box(
                modifier = Modifier
                    .fillMaxWidth(0.4f)
                    .aspectRatio(1f)
                    .padding(top = 60.dp),
                contentAlignment = Alignment.Center
            ) {
                // Target frame border
                androidx.compose.foundation.Canvas(
                    modifier = Modifier.fillMaxSize()
                ) {
                    drawRect(
                        color = Color.White,
                        style = androidx.compose.ui.graphics.drawscope.Stroke(width = 10f)
                    )
                }

                // Center dot
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(Color.Red, CircleShape)
                        .align(Alignment.TopStart)
                        .offset(100.dp, 100.dp)
                )

                // Sensor icons at corners (matching iOS positioning)
                val sensorSize = 24.dp
                val sensorOffset = 4.dp

                // Bottom-left sensor (positioned outside the frame)
                Box(
                    modifier = Modifier
                        .size(sensorSize)
                        .scale(if (!bleManager.isConnected) scaleAnimation.value else 0.9f)
                        .rotate(-45f)
                        .align(Alignment.BottomStart)
                        .offset(x = -sensorOffset, y = sensorOffset)
                ) {
                    Text(
                        text = "📡",
                        
                        
                        color = Color.White.copy(alpha = if (!bleManager.isConnected) opacityAnimation.value else 0.6f)
                    )
                }

                // Bottom-right sensor
                Box(
                    modifier = Modifier
                        .size(sensorSize)
                        .scale(if (!bleManager.isConnected) scaleAnimation.value else 0.9f)
                        .rotate(-135f)
                        .align(Alignment.BottomEnd)
                        .offset(x = sensorOffset, y = sensorOffset)
                ) {
                    Text(
                        text = "📡",
                        
                        
                        color = Color.White.copy(alpha = if (!bleManager.isConnected) opacityAnimation.value else 0.6f)
                    )
                }

                // Top-right sensor
                Box(
                    modifier = Modifier
                        .size(sensorSize)
                        .scale(if (!bleManager.isConnected) scaleAnimation.value else 0.9f)
                        .rotate(135f)
                        .align(Alignment.TopEnd)
                        .offset(x = sensorOffset, y = -sensorOffset)
                ) {
                    Text(
                        text = "📡",
                        
                        
                        color = Color.White.copy(alpha = if (!bleManager.isConnected) opacityAnimation.value else 0.6f)
                    )
                }

                // Top-left sensor
                Box(
                    modifier = Modifier
                        .size(sensorSize)
                        .scale(if (!bleManager.isConnected) scaleAnimation.value else 0.9f)
                        .rotate(45f)
                        .align(Alignment.TopStart)
                        .offset(x = -sensorOffset, y = -sensorOffset)
                ) {
                    Text(
                        text = "📡",
                        
                        
                        color = Color.White.copy(alpha = if (!bleManager.isConnected) opacityAnimation.value else 0.6f)
                    )
                }
            }

            // Status and Controls
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 120.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Status text with progress indicator
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = statusText,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center
                    )

                    if (showProgress) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                    }
                }

                // Reconnect button
                if (showReconnect) {
                    Button(
                        onClick = { handleReconnect() },
                        modifier = Modifier
                            .fillMaxWidth(0.75f)
                            .height(44.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "Reconnect",
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                // Connected state buttons
                if (isAlreadyConnected) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterHorizontally)
                    ) {
                        Button(
                            onClick = {
                                bleManager.disconnect()
                                onDismiss()
                            },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "Disconnect",
                                color = Color.White,
                                fontSize = 16.sp
                            )
                        }

                        Button(
                            onClick = { showFirmwareAlert = true },
                            modifier = Modifier
                                .weight(1f)
                                .height(44.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(
                                text = "Firmware",
                                color = Color.White,
                                fontSize = 16.sp
                            )
                        }
                    }

                    // Image Transfer button
                    Button(
                        onClick = {
                            showImageCrop = true
                        },
                        modifier = Modifier
                            .fillMaxWidth(0.75f)
                            .height(44.dp)
                            .padding(top = 4.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Blue),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            text = "My Target",
                            color = Color.White,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }

        // Close button (top right)
        IconButton(
            onClick = onDismiss,
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(20.dp)
                .size(44.dp)
                .background(Color.White.copy(alpha = 0.2f), CircleShape)
        ) {
            Text(
                text = "✕",
                color = Color.White,
                fontSize = 20.sp
            )
        }

        // Firmware upgrade alert
        if (showFirmwareAlert) {
            AlertDialog(
                onDismissRequest = { showFirmwareAlert = false },
                title = { Text("Firmware Upgrade") },
                text = { Text("Are you sure you want to upgrade the firmware?") },
                confirmButton = {
                    TextButton(
                        onClick = {
                            showFirmwareAlert = false
                            // TODO: Implement firmware upgrade
                            goToMain()
                        }
                    ) {
                        Text("OK")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showFirmwareAlert = false }) {
                        Text("Cancel")
                    }
                }
            )
        }

        // Error alert
        bleManager.error?.let { error ->
            AlertDialog(
                onDismissRequest = { /* Handle dismiss */ },
                title = { Text("Error") },
                text = { Text(error.message ?: "Unknown error occurred") },
                confirmButton = {
                    TextButton(onClick = { /* Handle OK */ }) {
                        Text("OK")
                    }
                }
            )
        }

        // Image Crop View
        if (showImageCrop) {
            ImageCropView(
                onDismiss = { showImageCrop = false },
                bleManager = bleManager
            )
        }
    }
}