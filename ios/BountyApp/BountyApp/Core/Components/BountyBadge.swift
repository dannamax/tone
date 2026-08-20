import SwiftUI

struct BountyBadge: View {
    let amount: Double
    let currency: String
    var fontSize: CGFloat = 16

    private var symbol: String {
        currency.uppercased() == "USD" ? "$" : "¥"
    }

    var body: some View {
        Text("\(symbol)\(String(format: "%.0f", amount))")
            .font(.system(size: fontSize, weight: .bold))
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
        case "pending": return .orange
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
