import SwiftUI

/// 金豆赏金徽章（任务卡/详情页通用）
struct BeansBadge: View {
    let beans: Int
    var fontSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "circle.circle.fill")
                .font(.system(size: fontSize * 0.7))
            Text("\(beans)")
                .font(.system(size: fontSize, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(LinearGradient(
                    colors: [Color(hex: "#FF8C52"), .bountyGold],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        )
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status {
        case "claimed": return .bountyInfo
        case "submitted": return .bountyGold
        case "completed": return .bountySuccess
        case "released": return .bountyGray
        case "disputed": return .bountyDanger
        default: return .bountyInfo
        }
    }

    var text: String {
        L10n.statusText(for: status)
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}
