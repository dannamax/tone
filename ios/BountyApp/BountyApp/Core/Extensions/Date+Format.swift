import SwiftUI

extension Date {
    func timeAgoDisplay() -> String {
        let interval = Date().timeIntervalSince(self)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .abbreviated
        if abs(interval) < 1 { return formatter.localizedString(fromTimeInterval: -1) }
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    func countdownText(from now: Date = Date()) -> String {
        let interval = self.timeIntervalSince(now)
        if interval <= 0 { return L10n.durationZero }
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remainMins = mins % 60
            return String(format: L10n.durationHourMin, hrs, remainMins)
        }
        return String(format: L10n.durationMinSec, mins, secs)
    }

    func isExpired() -> Bool {
        return Date() > self
    }

    func formatMedium() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

extension String {
    func distanceDisplay(_ meters: Double) -> String {
        if AppLocale.usesMetric {
            if meters < 1000 {
                return String(format: L10n.distanceMeter, meters)
            }
            return String(format: L10n.distanceKm, meters / 1000)
        }
        // 英制（美国/英国）：短距离英尺，长距离英里
        let miles = meters / 1609.344
        if miles < 0.1 {
            return String(format: L10n.distanceFt, meters * 3.28084)
        }
        return String(format: L10n.distanceMi, miles)
    }
}

/// 距离单位：跟随系统区域设置（美国用户 miles，其余 km），
/// App 内语言切换不影响单位（区域才决定度量衡习惯）。
enum AppLocale {
    static var usesMetric: Bool {
        Locale.current.usesMetricSystem
    }

    /// 任务半径显示：metric → "5km"；imperial → "3.1 mi"
    static func radiusDisplay(_ meters: Int) -> String {
        if usesMetric {
            if meters < 1000 {
                return "\(meters)m"
            }
            let km = Double(meters) / 1000
            return km == km.rounded() ? String(format: "%.0fkm", km) : String(format: "%.1fkm", km)
        }
        return String(format: "%.1f mi", Double(meters) / 1609.344)
    }
}
