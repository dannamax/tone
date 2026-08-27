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
    /// 解析后端 ISO8601/SQLite 时间字符串并转为相对时间展示（"2h ago"）。
    /// SQLite CURRENT_TIMESTAMP 格式为 "2006-01-02 15:04:05"（UTC 无时区）；
    /// 兼容 RFC3339（带 Z/时区偏移）两种形态。
    var iso8601TimeAgo: String {
        let formats = [
            "yyyy-MM-dd HH:mm:ss",       // SQLite CURRENT_TIMESTAMP（UTC）
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ", // RFC3339 带 时区
            "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            // SQLite 形态无时区，按 UTC 解释
            if fmt == formats[0] { df.timeZone = TimeZone(identifier: "UTC") }
            if let date = df.date(from: self) {
                return date.timeAgoDisplay()
            }
        }
        return self
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
