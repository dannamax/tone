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
        if meters < 1000 {
            return String(format: L10n.distanceMeter, meters)
        }
        return String(format: L10n.distanceKm, meters / 1000)
    }
}
