package com.flextarget.android.ui.imagecrop

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import com.flextarget.android.data.ble.ImageTransferManager
import kotlinx.coroutines.launch

@Composable
fun ImageCropView(
    onDismiss: () -> Unit,
    bleManager: com.flextarget.android.data.ble.BLEManager = com.flextarget.android.data.ble.BLEManager.shared
) {
    val viewModel: ImageCropViewModel = viewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // State for image picker
    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let {
            scope.launch {
                try {
                    context.contentResolver.openInputStream(it)?.use { stream ->
                        val bitmap = BitmapFactory.decodeStream(stream)
                        bitmap?.let { bmp ->
                            viewModel.setSelectedImage(bmp)
                        }
                    }
                } catch (e: Exception) {
                    // Handle error
                }
            }
        }
    }

    // State for transfer
    var showTransferDialog by remember { mutableStateOf(false) }
    var transferProgress by remember { mutableStateOf(0) }
    var transferState by remember { mutableStateOf(TransferState.Waiting) }

    // Canvas dimensions (9:16 portrait ratio)
    val canvasRatio: Float = 9.0f / 16.0f
    val containerHeight = 480.dp

    // Compute guide aspect from custom-target-guide drawable
    val guideAspect by remember {
        mutableStateOf(
            // Assuming the guide image has aspect ratio similar to iOS
            720f / 1280f // 9:16 aspect ratio
        )
    }

    // Container and guide sizes
    var currentContainerSize by remember { mutableStateOf(Size.Zero) }
    var currentGuideSize by remember { mutableStateOf(Size.Zero) }

    fun computeGuideSize(containerSize: Size): Size {
        if (guideAspect > 0f) {
            val containerAspect = containerSize.width / containerSize.height
            if (guideAspect > containerAspect) {
                // guide is wider than container -> fit width
                val w = containerSize.width
                val h = w / guideAspect
                return Size(w, h)
            } else {
                // guide is taller (or equal) -> fit height
                val h = containerSize.height
                val w = (h * guideAspect).coerceAtMost(containerSize.width)
                return Size(w, h)
            }
        } else {
            // unknown aspect: fallback to full container
            return containerSize
        }
    }

    LaunchedEffect(currentContainerSize) {
        if (currentContainerSize != Size.Zero) {
            currentGuideSize = computeGuideSize(currentContainerSize)
            viewModel.enforceConstraints(currentContainerSize, currentGuideSize)
        }
    }

    LaunchedEffect(viewModel.selectedImage) {
        if (currentContainerSize != Size.Zero) {
            viewModel.enforceConstraints(currentContainerSize, currentGuideSize)
        }
    }

    LaunchedEffect(viewModel.scale) {
        if (currentContainerSize != Size.Zero) {
            viewModel.enforceConstraints(currentContainerSize, currentGuideSize)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Main Canvas Area
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(containerHeight)
                    .background(Color.Black)
            ) {
                androidx.compose.foundation.layout.BoxWithConstraints(
                    modifier = Modifier.fillMaxSize()
                ) {
                    val containerSize = Size(maxWidth.value, maxHeight.value)
                    currentContainerSize = containerSize
                    val guideSize = computeGuideSize(containerSize)
                    currentGuideSize = guideSize
                    val cropSize = guideSize

                    // Main canvas content
                    Box(modifier = Modifier.fillMaxSize()) {
                        // Selected image with pan/zoom
                        viewModel.selectedImage.value?.let { bitmap ->
                            val effectiveOffset = viewModel.clampedOffset(
                                viewModel.offset.value,
                                containerSize,
                                cropSize
                            )

                            androidx.compose.foundation.Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = null,
                                contentScale = ContentScale.FillBounds,
                                modifier = Modifier
                                    .fillMaxSize()
                                    .graphicsLayer(
                                        scaleX = viewModel.scale.value,
                                        scaleY = viewModel.scale.value,
                                        translationX = effectiveOffset.x,
                                        translationY = effectiveOffset.y
                                    )
                                    .pointerInput(Unit) {
                                        detectTransformGestures { centroid, pan, zoom, rotation ->
                                            val newScale = (viewModel.scale.value * zoom).coerceIn(viewModel.minScale, viewModel.maxScale)
                                            viewModel.updateScale(newScale)

                                            val proposedOffset = Offset(
                                                viewModel.offset.value.x + pan.x,
                                                viewModel.offset.value.y + pan.y
                                            )
                                            val clamped = viewModel.clampedOffset(proposedOffset, containerSize, cropSize)
                                            viewModel.updateOffset(clamped)
                                        }
                                    }
                            )
                        }

                        // Cropped preview
                        viewModel.croppedImage.value?.let { croppedBitmap ->
                            androidx.compose.foundation.Image(
                                bitmap = croppedBitmap.asImageBitmap(),
                                contentDescription = null,
                                contentScale = ContentScale.FillBounds,
                                modifier = Modifier
                                    .size(
                                        width = guideSize.width.dp,
                                        height = guideSize.height.dp
                                    )
                                    .align(Alignment.Center)
                            )
                        }

                        // Guide overlay (custom-target-guide)
                        androidx.compose.foundation.Canvas(modifier = Modifier
                            .size(
                                width = guideSize.width.dp,
                                height = guideSize.height.dp
                            )
                            .align(Alignment.Center)
                        ) {
                            // Draw a simple guide rectangle
                            drawRect(
                                color = Color.White.copy(alpha = 0.5f),
                                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2f)
                            )
                        }

                        // Border overlay (custom-target-border)
                        androidx.compose.foundation.Canvas(modifier = Modifier
                            .size(
                                width = (guideSize.width + 20).dp, // Add some padding for border
                                height = (guideSize.height + 20).dp
                            )
                            .align(Alignment.Center)
                        ) {
                            // Draw a simple border rectangle
                            drawRect(
                                color = Color.Red.copy(alpha = 0.7f),
                                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 4f)
                            )
                        }
                    }
                }
            }

            // Controls Section
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Black)
                    .padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.weight(1f))

                // Choose Photo Button
                Button(
                    onClick = { imagePickerLauncher.launch("image/*") },
                    modifier = Modifier
                        .fillMaxWidth(0.75f)
                        .height(44.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Gray),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text("📷", fontSize = MaterialTheme.typography.bodyLarge.fontSize)
                        Text(
                            "Choose Photo",
                            color = Color.White,
                            fontSize = MaterialTheme.typography.bodyLarge.fontSize
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))
            }
        }

        // Top navigation bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Back button
            IconButton(onClick = {
                if (showTransferDialog) {
                    // Cancel transfer if in progress
                    showTransferDialog = false
                    viewModel.clearCroppedImage()
                } else {
                    onDismiss()
                }
            }) {
                Text("←", color = Color.White, fontSize = MaterialTheme.typography.headlineMedium.fontSize)
            }

            // Transfer button (only show when image is selected)
            if (viewModel.selectedImage.value != null) {
                Button(
                    onClick = {
                        // Compute crop frame
                        val container = currentContainerSize
                        val guide = currentGuideSize

                        // Inset the guide by the border width to avoid cropping into the white border
                        val inset: Float = 20f // 10dp * 2 for border
                        val cropWidth = (guide.width - inset).coerceAtLeast(10f)
                        val cropHeight = (guide.height - inset).coerceAtLeast(10f)
                        val originX = (container.width - cropWidth) / 2.0f
                        val originY = (container.height - cropHeight) / 2.0f
                        val cropFrame = Rect(originX, originY, originX + cropWidth, originY + cropHeight)

                        // Perform crop
                        viewModel.cropImage(cropFrame, container)

                        // Start transfer if we have a cropped image
                        viewModel.croppedImage.value?.let { cropped ->
                            val transferManager = ImageTransferManager(bleManager)
                            showTransferDialog = true
                            transferState = TransferState.Waiting

                            transferManager.transferImage(
                                cropped,
                                imageName = "cropped-target",
                                progress = { progress ->
                                    transferProgress = progress
                                    transferState = TransferState.Transferring
                                },
                                completion = { success, message ->
                                    if (success) {
                                        transferState = TransferState.Success
                                        viewModel.clearSelectedImage()
                                        // Auto-dismiss after success
                                        scope.launch {
                                            kotlinx.coroutines.delay(2000)
                                            showTransferDialog = false
                                            onDismiss()
                                        }
                                    } else {
                                        transferState = TransferState.Failed
                                        // Keep dialog open to show error
                                    }
                                }
                            )
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        "Transfer",
                        color = Color.White,
                        fontSize = MaterialTheme.typography.bodyLarge.fontSize
                    )
                }
            }
        }

        // Transfer Progress Dialog
        if (showTransferDialog) {
            Dialog(onDismissRequest = { /* Prevent dismiss during transfer */ }) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.White)
                            .padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        when (transferState) {
                            TransferState.Waiting -> {
                                Text(
                                    "Ensure target is ready",
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = Color.Black
                                )
                                CircularProgressIndicator(color = Color.Red)
                                Button(
                                    onClick = {
                                        showTransferDialog = false
                                        viewModel.clearCroppedImage()
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.White),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color.Red)
                                ) {
                                    Text("Cancel", color = Color.Red)
                                }
                            }
                            TransferState.Transferring -> {
                                Text(
                                    "Transferring image...",
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = Color.Black
                                )
                                LinearProgressIndicator(
                                    progress = transferProgress / 100f,
                                    color = Color.Red,
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Text("$transferProgress%", color = Color.Black)
                                Button(
                                    onClick = {
                                        showTransferDialog = false
                                        viewModel.clearCroppedImage()
                                    },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.White),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color.Red)
                                ) {
                                    Text("Cancel", color = Color.Red)
                                }
                            }
                            TransferState.Success -> {
                                Text(
                                    "Transfer complete!",
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = Color.Green
                                )
                                Icon(
                                    painter = painterResource(id = android.R.drawable.ic_dialog_info),
                                    contentDescription = null,
                                    tint = Color.Green
                                )
                            }
                            TransferState.Failed -> {
                                Text(
                                    "Transfer failed",
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = Color.Red
                                )
                                Text(
                                    "Please try again",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Color.Black
                                )
                                Button(
                                    onClick = { showTransferDialog = false },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                                ) {
                                    Text("OK", color = Color.White)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

enum class TransferState {
    Waiting,
    Transferring,
    Success,
    Failed
}