import SwiftUI

extension Color {
    static let bountyGold = Color(hex: "#FF6B35")
    static let bountyDark = Color(hex: "#1A1A2E")
    static let bountyGray = Color(hex: "#6C757D")
    static let bountyBg = Color(hex: "#F8F9FA")
    static let bountySuccess = Color(hex: "#28A745")
    static let bountyDanger = Color(hex: "#DC3545")
    static let bountyWarning = Color(hex: "#FFC107")
    static let bountyInfo = Color(hex: "#0D6EFD")
    static let bountyCardBg = Color.white
    static let bountyText = Color(hex: "#212529")
    static let bountyTextSecondary = Color(hex: "#6C757D")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
