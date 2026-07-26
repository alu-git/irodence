import SwiftUI

/// Floating rest-timer banner shown after completing a set.
struct RestTimerView: View {
    @Binding var restEndsAt: Date?
    @Binding var duration: TimeInterval
    @State private var isPulsing = false

    private let presets: [TimeInterval] = [60, 90, 120, 180, 300]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            if let endsAt = restEndsAt {
                let remaining = endsAt.timeIntervalSince(context.date)
                if remaining <= 0 {
                    Color.clear.onAppear { restEndsAt = nil }
                } else {
                    banner(remaining: remaining)
                }
            }
        }
    }

    private func banner(remaining: TimeInterval) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "timer")
                .foregroundStyle(remaining < 10 ? Color.orange : Color.secondary)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text(timeString(remaining))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(remaining < 10 ? .orange : .primary)

            Spacer()

            Menu {
                ForEach(presets, id: \.self) { preset in
                    Button(timeString(preset)) {
                        duration = preset
                        restEndsAt = Date().addingTimeInterval(preset)
                    }
                }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }

            Button {
                restEndsAt = (restEndsAt ?? Date()).addingTimeInterval(30)
            } label: {
                Text("+30s")
                    .font(.subheadline.weight(.medium))
            }

            Button {
                restEndsAt = nil
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 8)
        .onAppear { isPulsing = true }
        .onDisappear { isPulsing = false }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
