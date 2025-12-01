import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

class ImageCropViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var croppedImage: UIImage?
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var showImagePicker = false
    @Published var showLivePreview = false
    
    // Calculated properties
    var minScale: CGFloat = 1.0
    var maxScale: CGFloat = 5.0
    
    func resetTransform() {
        scale = 1.0
        offset = .zero
    }

    /// Enforce minimum scale so the image always fills the provided cropSize
    /// and clamp offset so the crop rectangle remains covered by the image.
    func enforceConstraints(containerSize: CGSize, cropSize: CGSize) {
        // Ensure the user-visible image (container frame scaled by `scale`) fully
        // covers the crop rectangle `cropSize`. Adjust `scale` if it's too small
        // and clamp the `offset` so the crop rect never reveals background.

        // Compute the minimum user scale needed so the displayed image covers the crop area.
        // displayed size = containerSize * scale, so requiredScale = cropSize / containerSize
        let requiredScaleX = cropSize.width / max(0.0001, containerSize.width)
        let requiredScaleY = cropSize.height / max(0.0001, containerSize.height)
        let minAllowedScale = max(1.0, requiredScaleX, requiredScaleY)

        if scale < minAllowedScale {
            scale = minAllowedScale
        }

        // Compute the displayed image size (points) after applying base fill scale and user scale.
        // If we have the image, calculate how the image is scaled to fill the container (scaledToFill semantics):
        //   baseFillScale = max(containerWidth / imageWidth, containerHeight / imageHeight)
        // Displayed image size = image.size * baseFillScale * userScale
        let (displayedWidth, displayedHeight): (CGFloat, CGFloat) = {
            if let img = selectedImage {
                let baseFill = max(containerSize.width / max(0.0001, img.size.width),
                                   containerSize.height / max(0.0001, img.size.height))
                return (img.size.width * baseFill * scale, img.size.height * baseFill * scale)
            } else {
                // Fallback to container-based calculation if no image is available
                return (containerSize.width * scale, containerSize.height * scale)
            }
        }()

        // Allowed half-range for the center offset so the crop rect stays fully covered.
        let allowedHalfX = max(0, (displayedWidth - cropSize.width) / 2.0)
        let allowedHalfY = max(0, (displayedHeight - cropSize.height) / 2.0)

        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            return Swift.min(Swift.max(value, lower), upper)
        }

        let clampedX = clamp(offset.width, -allowedHalfX, allowedHalfX)
        let clampedY = clamp(offset.height, -allowedHalfY, allowedHalfY)

        offset = CGSize(width: clampedX, height: clampedY)
    }

    /// Return a clamped offset for a proposed offset without mutating state.
    func clampedOffset(for proposed: CGSize, containerSize: CGSize, cropSize: CGSize, scaleOverride: CGFloat? = nil) -> CGSize {
        // Allow clamping even when `selectedImage` is nil; the math doesn't need the UIImage itself.
        let effectiveScale = scaleOverride ?? scale

        // Displayed image size (points) = container frame size * effective scale
        // Compute displayed image size (points) using image intrinsic size when possible
        let (displayedWidth, displayedHeight): (CGFloat, CGFloat) = {
            if let img = selectedImage {
                let baseFill = max(containerSize.width / max(0.0001, img.size.width),
                                   containerSize.height / max(0.0001, img.size.height))
                return (img.size.width * baseFill * effectiveScale, img.size.height * baseFill * effectiveScale)
            } else {
                return (containerSize.width * effectiveScale, containerSize.height * effectiveScale)
            }
        }()

        // Allowed half-range for the center offset so the crop rect remains fully covered
        let allowedHalfX = max(0, (displayedWidth - cropSize.width) / 2.0 + 10)
        let allowedHalfY = max(0, (displayedHeight - cropSize.height) / 2.0 + 10)

        // Helper to clamp a single value into [lower, upper]
        func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
            return Swift.min(Swift.max(value, lower), upper)
        }

        let clampedX = clamp(proposed.width, -allowedHalfX, allowedHalfX)
        let clampedY = clamp(proposed.height, -allowedHalfY, allowedHalfY)

        return CGSize(width: clampedX, height: clampedY)
    }
    
    func cropImage(within cropFrame: CGRect, canvasSize: CGSize) {
        guard let image = selectedImage, let cg = image.cgImage else { return }

        // Compute baseFillScale (how the image was scaled to fill the container before user scale)
        let baseFill = max(canvasSize.width / max(0.0001, image.size.width),
                           canvasSize.height / max(0.0001, image.size.height))

        // The displayed image size in points after baseFill and user scale
        let displayedImageSize = CGSize(width: image.size.width * baseFill * scale,
                                        height: image.size.height * baseFill * scale)

        // Top-left of the displayed image inside the container (points)
        let imageOrigin = CGPoint(x: (canvasSize.width - displayedImageSize.width) / 2.0 + offset.width,
                                  y: (canvasSize.height - displayedImageSize.height) / 2.0 + offset.height)

        // Convert cropFrame (in container points) to image points: (point - imageOrigin) / (baseFill * scale)
        let invScale = 1.0 / (baseFill * scale)

        let imgX = (cropFrame.minX - imageOrigin.x) * invScale
        let imgY = (cropFrame.minY - imageOrigin.y) * invScale
        let imgW = cropFrame.width * invScale
        let imgH = cropFrame.height * invScale

        // Convert image points to image pixels (cgImage coordinate) using image.scale
        let pxPerPoint = image.scale
        let origin = CGPoint(x: CGFloat(imgX * pxPerPoint), y: CGFloat(imgY * pxPerPoint))
        let size = CGSize(width: CGFloat(imgW * pxPerPoint), height: CGFloat(imgH * pxPerPoint))
        var cropRectPixels = CGRect(origin: origin, size: size)

        // Clamp to cgImage bounds
        cropRectPixels.origin.x = max(0, cropRectPixels.origin.x)
        cropRectPixels.origin.y = max(0, cropRectPixels.origin.y)
        if cropRectPixels.maxX > CGFloat(cg.width) {
            cropRectPixels.size.width = max(0, CGFloat(cg.width) - cropRectPixels.origin.x)
        }
        if cropRectPixels.maxY > CGFloat(cg.height) {
            cropRectPixels.size.height = max(0, CGFloat(cg.height) - cropRectPixels.origin.y)
        }

        if let cropped = cg.cropping(to: cropRectPixels) {
    #if canImport(UIKit)
            self.croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    #endif
        }
    }
    
    func getImagePosition(in size: CGSize) -> CGPoint {
        let imageWidth = size.width * scale
        let imageHeight = size.height * scale
        
        let x = (size.width - imageWidth) / 2 + offset.width
        let y = (size.height - imageHeight) / 2 + offset.height
        
        return CGPoint(x: x, y: y)
    }
    
    func getImageSize(in size: CGSize) -> CGSize {
        guard let image = selectedImage else { return .zero }
        
        let aspectRatio = image.size.width / image.size.height
        let scaledHeight = size.height * scale
        let scaledWidth = scaledHeight * aspectRatio
        
        return CGSize(width: scaledWidth, height: scaledHeight)
    }
}
