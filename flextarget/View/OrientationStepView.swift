import SwiftUI
import AVKit

struct OrientationStepView: View {
    @Binding var step: OrientationStep
    @State private var player = AVPlayer()
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var timeObserverToken: Any?
    var onNext: (() -> Void)? = nil
    var onStepCompleted: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Video Player (top 2/3)
                VideoPlayer(player: player)
                .background(Color.black)
                .onAppear {
                    loadVideo()
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                        step.isCompleted = true
                        onStepCompleted?()
                    }
                }
                .onDisappear {
                    player.pause()
                    // Remove time observer
                    if let token = timeObserverToken {
                        player.removeTimeObserver(token)
                        timeObserverToken = nil
                    }
                }
                .frame(height: geometry.size.height * 2 / 3)
                .ignoresSafeArea(edges: .top)
                
                // Video Controls
                VStack(spacing: 16) {
                    // Progress Bar
                    VStack(spacing: 4) {
                        ProgressView(value: duration > 0 ? currentTime / duration : 0)
                            .progressViewStyle(.linear)
                            .accentColor(.red)
                            .frame(height: 4)
                            .padding(.horizontal, 8)
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption2)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatTime(duration))
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                    }
                    .background(Color.black.opacity(0.5))
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            let newTime = max(currentTime - 10, 0)
                            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                            currentTime = newTime
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.system(size: 20))
                        }
                        
                        Button(action: {
                            isPlaying.toggle()
                            if isPlaying {
                                player.play()
                            } else {
                                player.pause()
                            }
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            let newTime = min(currentTime + 10, duration)
                            player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                            currentTime = newTime
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.system(size: 20))
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                
                // Title, Subtitle, and Red Circle Arrow
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.step)
                            .font(.largeTitle)
                            .bold()
                        Text(step.title)
                            .font(.largeTitle)
                            .bold()
                        Text(step.subTitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    Button(action: {
                        onNext?()
                        loadVideo()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 44, height: 44)
                            Image(systemName: "arrow.right")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                Spacer()
            }//Top Level VStack\
            .background(Color.black).ignoresSafeArea()
            .foregroundColor(.white)
            
        } //Top Level Geo Reader
    }//View Body
    
    // Helper to format time as mm:ss
    func formatTime(_ time: Double) -> String {
        guard time.isFinite else { return "0:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadVideo() {
        // Reset player state
        player.replaceCurrentItem(with: AVPlayerItem(url: step.videoURL))
        player.play()
        isPlaying = true
        duration = player.currentItem?.asset.duration.seconds ?? 1
        if let asset = player.currentItem?.asset {
            Task {
                let durationValue = try? await asset.load(.duration).seconds
                duration = durationValue ?? 1
            }
        }
        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime = time.seconds
            duration = player.currentItem?.duration.seconds ?? 1
        }
    }
}

// View extension for conditional modifier
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
