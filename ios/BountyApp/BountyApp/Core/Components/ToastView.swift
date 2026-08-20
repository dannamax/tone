import SwiftUI

// MARK: - Toast
struct ToastView: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .bountyDanger : .bountySuccess)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82))
        .cornerRadius(10)
        .shadow(radius: 8)
    }
}

// MARK: - EmptyState
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String = ""
    var actionLabel: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 46))
                .foregroundColor(.bountyGray.opacity(0.6))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.bountyText)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.bountyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let action, !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.bountyGold)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Skeleton
struct SkeletonCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.bountyBg)
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.bountyGray.opacity(0.15))
            )
            .redacted(reason: .placeholder)
            .shimmering()
    }
}

// 简单闪烁效果
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 400 } }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
