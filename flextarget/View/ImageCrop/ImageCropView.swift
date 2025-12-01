import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ImageCropView: View {
    @StateObject private var viewModel = ImageCropViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var guideAspect: CGFloat? = nil
    
    // Canvas dimensions (9:16 portrait ratio)
    let canvasRatio: CGFloat = 9.0 / 16.0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main Canvas Area
                let containerHeight: CGFloat = 480
                GeometryReader { geo in
                    let containerSize = CGSize(width: geo.size.width, height: containerHeight)
                    // Compute the guide's displayed size (preserve asset aspect) and use it as the crop area
                    let guideSize: CGSize = {
                        if let aspect = guideAspect {
                            let containerAspect = containerSize.width / containerSize.height
                            if aspect > containerAspect {
                                // guide is wider than container -> fit width
                                let w = containerSize.width
                                let h = w / aspect
                                return CGSize(width: w, height: h)
                            } else {
                                // guide is taller (or equal) -> fit height
                                let h = containerSize.height
                                let w = min(containerSize.width, h * aspect)
                                return CGSize(width: w, height: h)
                            }
                        } else {
                            // unknown aspect: fallback to full container
                            return containerSize
                        }
                    }()
                    // cropSize is the guide's visible size
                    let cropSize = guideSize
                    
                    ZStack {
                        if let image = viewModel.selectedImage {
                            // Image fill area
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: containerHeight)
                                .scaleEffect(viewModel.scale, anchor: .center)
                                // Compute effective offset (offset + dragTranslation) clamped to allowed range
                                .offset(x: viewModel.clampedOffset(for: CGSize(width: viewModel.offset.width + dragTranslation.width,
                                                                               height: viewModel.offset.height + dragTranslation.height), containerSize: containerSize, cropSize: cropSize).width,
                                        y: viewModel.clampedOffset(for: CGSize(width: viewModel.offset.width + dragTranslation.width,
                                                                               height: viewModel.offset.height + dragTranslation.height), containerSize: containerSize, cropSize: cropSize).height)
                                .clipped()
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            // Compute the proposed absolute offset and clamp it immediately
                                            let proposed = CGSize(width: viewModel.offset.width + value.translation.width,
                                                                  height: viewModel.offset.height + value.translation.height)
                                            let clamped = viewModel.clampedOffset(for: proposed, containerSize: containerSize, cropSize: cropSize)
                                            // Show the clamped translation while dragging
                                            dragTranslation = CGSize(width: clamped.width - viewModel.offset.width,
                                                                     height: clamped.height - viewModel.offset.height)
                                        }
                                        .onEnded { _ in
                                            // Commit clamped offset
                                            let proposed = CGSize(width: viewModel.offset.width + dragTranslation.width,
                                                                  height: viewModel.offset.height + dragTranslation.height)
                                            viewModel.offset = viewModel.clampedOffset(for: proposed, containerSize: containerSize, cropSize: cropSize)
                                            dragTranslation = .zero
                                        }
                                )
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            // value is relative to the gesture start; combine with lastScale
                                            pinchScale = value
                                            let proposed = lastScale * pinchScale
                                            let clamped = min(max(proposed, viewModel.minScale), viewModel.maxScale)
                                            viewModel.scale = clamped
                                            // clamp offset live so zoom doesn't reveal background
                                            viewModel.offset = viewModel.clampedOffset(for: viewModel.offset, containerSize: containerSize, cropSize: cropSize, scaleOverride: viewModel.scale)
                                        }
                                        .onEnded { _ in
                                            lastScale = viewModel.scale
                                            pinchScale = 1.0
                                        }
                                )
                                .onChange(of: viewModel.scale) { _ in
                                    viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                                }
                                .onAppear {
                                    viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                                }
                                .onChange(of: viewModel.selectedImage) { _ in
                                    viewModel.enforceConstraints(containerSize: containerSize, cropSize: cropSize)
                                }
                        }
                        
                        // Crop guide image from Assets (vector PDF/SVG as asset)
                        Image("custom-target-guide")
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: guideSize.width, height: guideSize.height)
                            .allowsHitTesting(false)
                            .onAppear {
                                // lazy-load asset aspect when UIKit is available
                                #if canImport(UIKit)
                                if guideAspect == nil {
                                    if let img = UIImage(named: "custom-target-guide") {
                                        let a = img.size.width / max(1.0, img.size.height)
                                        guideAspect = a
                                    }
                                }
                                #endif
                            }
                    }
                    .frame(height: containerHeight)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                }
                .frame(height: containerHeight)
                
                // Controls Section
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            HStack(spacing: 10) {
                                Image(systemName: "photo.fill")
                                Text("Choose Photo")
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 18)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .contentShape(Rectangle())
                            .frame(minHeight: 44)
                        }
                        .onChange(of: selectedPhotoItem) { newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    await MainActor.run {
                                        viewModel.selectedImage = uiImage
                                        viewModel.resetTransform()
                                        lastOffset = .zero
                                        dragTranslation = .zero
                                    }
                                }
                            }
                        }

                        // Apply Crop moved to navigation bar as 'Complete'
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    Spacer()
                }
                .frame(minHeight: 120)
                .background(Color.black)
            }
            .navigationTitle("Position & Crop")
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.backward")
                                // Text("Back")
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if viewModel.selectedImage != nil {
                            Button("Complete") {
                                // TODO: perform crop and dismiss/return result
                            }
                        }
                    }
                }
            .sheet(isPresented: $viewModel.showLivePreview) {
                LivePreviewSheet(viewModel: viewModel)
            }
            .onAppear {
                // ensure guideAspect is available as early as possible so clamping uses guide bounds
                #if canImport(UIKit)
                if guideAspect == nil, let img = UIImage(named: "custom-target-guide") {
                    guideAspect = img.size.width / max(1.0, img.size.height)
                }
                #endif
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

struct LivePreviewSheet: View {
    @ObservedObject var viewModel: ImageCropViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main preview with mask
                ZStack {
                    if let image = viewModel.selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(viewModel.scale)
                            .offset(viewModel.offset)
                    }
                    
                    // Crop guide image for preview (matches preview frame)
                    Image("custom-target-guide")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 320)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .clipped()
                .background(Color.black)
                
                // Information
                VStack(spacing: 12) {
                    Text("Live Preview")
                        .font(.headline)
                    Text("This shows how your photo will be positioned and cropped with the silhouette guide.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Text("Zoom Level:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1fx", viewModel.scale))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Offset:")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "x: %.0f, y: %.0f", viewModel.offset.width, viewModel.offset.height))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Close Preview")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(16)
            }
            .navigationTitle("Live Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ImageCropView()
}

// (Crop guide now provided by the `customer-image-guide` asset in Assets.xcassets)
