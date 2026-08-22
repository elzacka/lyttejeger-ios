import Foundation

/// Format seconds to mm:ss or hh:mm:ss
func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }

    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%d:%02d", minutes, secs)
}

/// Format duration for display (e.g., "45 min" or "1 t 23 min")
func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds > 0 else { return "" }

    let totalMinutes = Int(seconds) / 60
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 {
        return minutes > 0 ? "\(hours) t \(minutes) min" : "\(hours) t"
    }
    // A 45-second trailer is not "0 min".
    guard totalMinutes > 0 else { return "\(Int(seconds)) sek" }
    return "\(totalMinutes) min"
}

private let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "nb_NO")
    f.dateFormat = "MMM yyyy"
    return f
}()

/// ISO 8601 formatter with fractional seconds (parses "2025-01-15T12:00:00.000Z")
nonisolated(unsafe) let iso8601Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

/// ISO 8601 formatter with default options (parses "2025-01-15T12:00:00Z")
nonisolated(unsafe) let iso8601BasicFormatter = ISO8601DateFormatter()

/// Format ISO date to short month + year (e.g., "jan. 2025")
func formatShortDate(_ dateString: String) -> String? {
    guard let date = iso8601Formatter.date(from: dateString) ?? iso8601BasicFormatter.date(from: dateString) else {
        return nil
    }
    return shortDateFormatter.string(from: date)
}

/// Format relative date (e.g., "I dag", "I går", "for 3 dager siden")
func formatRelativeDate(_ dateString: String) -> String {
    guard let date = iso8601Formatter.date(from: dateString) ?? iso8601BasicFormatter.date(from: dateString) else {
        return dateString
    }

    // Compare calendar days, not 24-hour periods: an episode published
    // yesterday evening is "I går" this morning, even though less than a
    // day has elapsed.
    let calendar = Calendar.current
    let components = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: date),
        to: calendar.startOfDay(for: Date())
    )

    guard let days = components.day else { return dateString }

    switch days {
    // Future-dated feeds happen; "I dag" beats "0 år siden".
    case ...0: return "I dag"
    case 1: return "I går"
    case 2...6: return "for \(days) dager siden"
    case 7...13: return "for 1 uke siden"
    case 14...29: return "for \(days / 7) uker siden"
    case 30...59: return "for 1 måned siden"
    case 60...364: return "for \(days / 30) måneder siden"
    default:
        let years = days / 365
        return years == 1 ? "for 1 år siden" : "for \(years) år siden"
    }
}
