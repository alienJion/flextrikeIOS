package com.flextarget.android.ui.imagecrop

import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.RectF
import androidx.compose.ui.geometry.Size
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class ImageCropViewModel : ViewModel() {
    private val _selectedImage = MutableStateFlow<Bitmap?>(null)
    val selectedImage: StateFlow<Bitmap?> = _selectedImage.asStateFlow()

    private val _croppedImage = MutableStateFlow<Bitmap?>(null)
    val croppedImage: StateFlow<Bitmap?> = _croppedImage.asStateFlow()

    private val _scale = MutableStateFlow(1.0f)
    val scale: StateFlow<Float> = _scale.asStateFlow()

    private val _offset = MutableStateFlow(androidx.compose.ui.geometry.Offset.Zero)
    val offset: StateFlow<androidx.compose.ui.geometry.Offset> = _offset.asStateFlow()

    // Calculated properties
    val minScale: Float = 1.0f
    val maxScale: Float = 5.0f

    fun setSelectedImage(bitmap: Bitmap?) {
        _selectedImage.value = bitmap
        resetTransform()
    }

    fun resetTransform() {
        _scale.value = 1.0f
        _offset.value = androidx.compose.ui.geometry.Offset.Zero
    }

    fun updateScale(newScale: Float) {
        _scale.value = newScale.coerceIn(minScale, maxScale)
    }

    fun updateOffset(newOffset: androidx.compose.ui.geometry.Offset) {
        _offset.value = newOffset
    }

    /// Enforce minimum scale so the image always fills the provided cropSize
    /// and clamp offset so the crop rectangle remains covered by the image.
    fun enforceConstraints(containerSize: Size, cropSize: Size) {
        val bitmap = _selectedImage.value ?: return

        // Ensure the user-visible image (container frame scaled by `scale`) fully
        // covers the crop rectangle `cropSize`. Adjust `scale` if it's too small
        // and clamp the `offset` so the crop rect never reveals background.

        // Compute the minimum user scale needed so the displayed image covers the crop area.
        // displayed size = containerSize * scale, so requiredScale = cropSize / containerSize
        val requiredScaleX = cropSize.width / containerSize.width.coerceAtLeast(0.0001f)
        val requiredScaleY = cropSize.height / containerSize.height.coerceAtLeast(0.0001f)
        val minAllowedScale = kotlin.math.max(1.0f, kotlin.math.max(requiredScaleX, requiredScaleY))

        if (_scale.value < minAllowedScale) {
            _scale.value = minAllowedScale
        }

        // Compute the displayed image size (points) after applying base fill scale and user scale.
        // If we have the image, calculate how the image is scaled to fill the container (scaledToFill semantics):
        //   baseFillScale = max(containerWidth / imageWidth, containerHeight / imageHeight)
        // Displayed image size = image.size * baseFillScale * userScale
        val baseFill = kotlin.math.max(containerSize.width / bitmap.width.toFloat(),
                          containerSize.height / bitmap.height.toFloat())

        val displayedWidth = bitmap.width * baseFill * _scale.value
        val displayedHeight = bitmap.height * baseFill * _scale.value

        // Allowed half-range for the center offset so the crop rect stays fully covered.
        val allowedHalfX = kotlin.math.max(0f, (displayedWidth - cropSize.width) / 2.0f)
        val allowedHalfY = kotlin.math.max(0f, (displayedHeight - cropSize.height) / 2.0f)

        val clampedX = _offset.value.x.coerceIn(-allowedHalfX, allowedHalfX)
        val clampedY = _offset.value.y.coerceIn(-allowedHalfY, allowedHalfY)

        _offset.value = androidx.compose.ui.geometry.Offset(clampedX, clampedY)
    }

    /// Return a clamped offset for a proposed offset without mutating state.
    fun clampedOffset(
        proposed: androidx.compose.ui.geometry.Offset,
        containerSize: Size,
        cropSize: Size,
        scaleOverride: Float? = null
    ): androidx.compose.ui.geometry.Offset {
        val bitmap = _selectedImage.value ?: return proposed
        val effectiveScale = scaleOverride ?: _scale.value

        // Displayed image size (points) = container frame size * effective scale
        // Compute displayed image size (points) using image intrinsic size when possible
        val baseFill = kotlin.math.max(containerSize.width / bitmap.width.toFloat(),
                          containerSize.height / bitmap.height.toFloat())

        val displayedWidth = bitmap.width * baseFill * effectiveScale
        val displayedHeight = bitmap.height * baseFill * effectiveScale

        // Allowed half-range for the center offset so the crop rect remains fully covered
        val allowedHalfX = kotlin.math.max(0f, (displayedWidth - cropSize.width) / 2.0f)
        val allowedHalfY = kotlin.math.max(0f, (displayedHeight - cropSize.height) / 2.0f)

        val clampedX = proposed.x.coerceIn(-allowedHalfX, allowedHalfX)
        val clampedY = proposed.y.coerceIn(-allowedHalfY, allowedHalfY)

        return androidx.compose.ui.geometry.Offset(clampedX, clampedY)
    }

    fun cropImage(cropFrame: androidx.compose.ui.geometry.Rect, canvasSize: Size) {
        val bitmap = _selectedImage.value ?: return

        // Compute baseFillScale using the bitmap size
        val baseFill = kotlin.math.max(canvasSize.width / bitmap.width.toFloat(),
                          canvasSize.height / bitmap.height.toFloat())

        // The displayed image size in points after baseFill and user scale
        val displayedImageSize = Size(
            width = bitmap.width * baseFill * _scale.value,
            height = bitmap.height * baseFill * _scale.value
        )

        // Top-left of the displayed image inside the container (points)
        val imageOrigin = androidx.compose.ui.geometry.Offset(
            x = (canvasSize.width - displayedImageSize.width) / 2.0f + _offset.value.x,
            y = (canvasSize.height - displayedImageSize.height) / 2.0f + _offset.value.y
        )

        // Convert cropFrame (in container points) to bitmap points: (point - imageOrigin) / (baseFill * scale)
        val invScale = 1.0f / (baseFill * _scale.value)

        val imgX = (cropFrame.left - imageOrigin.x) * invScale
        val imgY = (cropFrame.top - imageOrigin.y) * invScale
        val imgW = cropFrame.width * invScale
        val imgH = cropFrame.height * invScale

        // Convert bitmap points to bitmap pixels
        val pxPerPoint = 1.0f // Bitmap coordinates are in pixels
        val originX = (imgX * pxPerPoint).toInt()
        val originY = (imgY * pxPerPoint).toInt()
        val width = (imgW * pxPerPoint).toInt()
        val height = (imgH * pxPerPoint).toInt()

        // Clamp to bitmap bounds
        val clampedOriginX = originX.coerceIn(0, bitmap.width)
        val clampedOriginY = originY.coerceIn(0, bitmap.height)
        val clampedWidth = kotlin.math.min(width, bitmap.width - clampedOriginX)
        val clampedHeight = kotlin.math.min(height, bitmap.height - clampedOriginY)

        // If the resulting rect is empty or too small, attempt a safe fallback
        if (clampedWidth < 1 || clampedHeight < 1) {
            // Fallback: create a centered crop that preserves the target aspect ratio
            // (720x1280) inside the available bitmap bounds.
            val targetSize = Size(720f, 1280f)
            val targetAspect = targetSize.width / targetSize.height

            // Start by trying to use full bitmap height and compute width by aspect
            var fallbackHeight = bitmap.height.toFloat()
            var fallbackWidth = fallbackHeight * targetAspect

            // If that width exceeds bounds, use full width and compute height by aspect
            if (fallbackWidth > bitmap.width) {
                fallbackWidth = bitmap.width.toFloat()
                fallbackHeight = fallbackWidth / targetAspect
            }

            val fx = (bitmap.width - fallbackWidth) / 2.0f
            val fy = (bitmap.height - fallbackHeight) / 2.0f

            val cropped = Bitmap.createBitmap(
                bitmap,
                fx.toInt(),
                fy.toInt(),
                fallbackWidth.toInt(),
                fallbackHeight.toInt()
            )

            // Resize to target output resolution (720x1280)
            val resized = Bitmap.createScaledBitmap(cropped, 720, 1280, true)
            _croppedImage.value = resized
            return
        }

        val cropped = Bitmap.createBitmap(
            bitmap,
            clampedOriginX,
            clampedOriginY,
            clampedWidth,
            clampedHeight
        )

        // Resize to target output resolution (720x1280) while preserving aspect ratio.
        // We scale the cropped image to fill the target area (aspect-fill), then draw it centered
        // into the target canvas so the final image is exactly targetSize but aspect ratio is preserved.
        val targetSize = Size(720f, 1280f)
        val srcSize = Size(cropped.width.toFloat(), cropped.height.toFloat())

        // Compute scale to fill target (preserve aspect ratio)
        val scaleX = targetSize.width / srcSize.width
        val scaleY = targetSize.height / srcSize.height
        val scaleToFill = kotlin.math.max(scaleX, scaleY)

        val scaledSize = Size(
            width = srcSize.width * scaleToFill,
            height = srcSize.height * scaleToFill
        )

        // Center the scaled image in the target canvas (may crop overflow)
        val drawOrigin = androidx.compose.ui.geometry.Offset(
            x = (targetSize.width - scaledSize.width) / 2.0f,
            y = (targetSize.height - scaledSize.height) / 2.0f
        )

        val resized = Bitmap.createBitmap(720, 1280, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(resized)
        val paint = android.graphics.Paint().apply {
            isFilterBitmap = true
            isAntiAlias = true
        }

        canvas.drawBitmap(
            cropped,
            android.graphics.Rect(0, 0, cropped.width, cropped.height),
            android.graphics.RectF(drawOrigin.x, drawOrigin.y, drawOrigin.x + scaledSize.width, drawOrigin.y + scaledSize.height),
            paint
        )

        _croppedImage.value = resized
    }

    fun clearCroppedImage() {
        _croppedImage.value = null
    }

    fun clearSelectedImage() {
        _selectedImage.value = null
        _croppedImage.value = null
        resetTransform()
    }
}