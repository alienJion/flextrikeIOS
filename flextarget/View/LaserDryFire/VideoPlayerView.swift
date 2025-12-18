import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VideoPlayerController(url: url, onComplete: onComplete)
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
    }
}

struct VideoPlayerController: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // Auto-play the video
        player.play()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    class Coordinator: NSObject {
        var onComplete: (() -> Void)?

        init(onComplete: (() -> Void)?) {
            self.onComplete = onComplete
        }

        @objc func playerDidFinishPlaying() {
            onComplete?()
        }
    }
}