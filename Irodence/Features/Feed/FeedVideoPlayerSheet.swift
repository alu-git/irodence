import SwiftUI
import AVKit

/// Custom industrial video player sheet with slow-motion analysis (0.5x/0.75x/1.0x)
/// specifically designed for gym lifters verifying lockout, depth, and form.
struct FeedVideoPlayerSheet: View {
    let videoURL: URL
    let title: String
    let subtitle: String?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var playbackRate: Float = 1.0
    @State private var isMuted = false
    @State private var showControls = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    private let availableRates: [Float] = [0.5, 0.75, 1.0]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                // Native AVPlayer layer
                CustomVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                    }

                // Overlay Controls
                if showControls {
                    VStack {
                        // Top Bar: Title + Close Button
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)

                                if let subtitle = subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.Colors.textMuted)
                                }
                            }

                            Spacer()

                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.lg)
                        .background(
                            LinearGradient(
                                colors: [Color.black.opacity(0.8), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Spacer()

                        // Center Play/Pause Large Button
                        Button {
                            togglePlayPause()
                        } label: {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Theme.Colors.ember.opacity(0.9))
                                .shadow(color: .black.opacity(0.6), radius: 10)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Bottom Control Bar
                        VStack(spacing: Theme.Spacing.sm) {
                            // Progress scrubber
                            HStack(spacing: 8) {
                                Text(formatTime(currentTime))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)

                                Slider(
                                    value: Binding(
                                        get: { currentTime },
                                        set: { newValue in
                                            seek(to: newValue)
                                        }
                                    ),
                                    in: 0...max(duration, 1.0)
                                )
                                .tint(Theme.Colors.ember)

                                Text(formatTime(duration))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                            .padding(.horizontal, Theme.Spacing.md)

                            // Quick Controls: Speed (Slow-mo) & Audio
                            HStack(spacing: Theme.Spacing.md) {
                                // Slow-motion rate picker
                                HStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Theme.Colors.ember)

                                    ForEach(availableRates, id: \.self) { rate in
                                        Button {
                                            setRate(rate)
                                        } label: {
                                            Text(rate == 1.0 ? "1.0×" : String(format: "%.2g×", rate))
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundStyle(playbackRate == rate ? Theme.Colors.textOnEmber : .white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    playbackRate == rate ? Theme.Colors.ember : Color.white.opacity(0.15),
                                                    in: RoundedRectangle(cornerRadius: 6)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Spacer()

                                // Mute / Unmute Button
                                Button {
                                    isMuted.toggle()
                                    player.isMuted = isMuted
                                    ForgeHaptics.selection()
                                } label: {
                                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(Color.white.opacity(0.15), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.lg)
                        }
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            } else {
                ProgressView()
                    .tint(Theme.Colors.ember)
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            tearDownPlayer()
        }
    }

    private func setupPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        self.player = avPlayer
        avPlayer.play()
        isPlaying = true

        // Observe duration
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time.seconds
            if let item = avPlayer.currentItem, item.duration.isValid && !item.duration.isIndefinite {
                self.duration = item.duration.seconds
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            self.isPlaying = false
            self.seek(to: 0)
        }
    }

    private func tearDownPlayer() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            ForgeHaptics.selection()
        } else {
            player.play()
            player.rate = playbackRate
            isPlaying = true
            ForgeHaptics.selection()
        }
    }

    private func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        ForgeHaptics.selection()
    }

    private func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Helper UIViewRepresentable wrapping AVPlayerViewController without native chrome for full custom UI
struct CustomVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
