import SwiftUI

struct CountdownBar: View {
    let expiresAt: Date
    @State private var remainingSeconds: Double = 0
    @State private var totalSeconds: Double = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(expiresAt: Date, totalMinutes: Int = 30) {
        self.expiresAt = expiresAt
        _totalSeconds = State(initialValue: Double(totalMinutes * 60))
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, remainingSeconds / totalSeconds))
    }

    var barColor: Color {
        if progress > 0.5 { return .bountySuccess }
        if progress > 0.2 { return .bountyWarning }
        return .bountyDanger
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.bountyBg)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.8), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(progress < 0.2 ? .bountyDanger : .bountyTextSecondary)
                Text(expiresAt.countdownText())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(progress < 0.2 ? .bountyDanger : .bountyTextSecondary)
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            remainingSeconds = max(0, expiresAt.timeIntervalSinceNow)
        }
        .onAppear {
            remainingSeconds = max(0, expiresAt.timeIntervalSinceNow)
        }
    }
}
