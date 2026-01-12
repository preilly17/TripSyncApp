import Foundation

enum TripDateFormatter {
    static let parseFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static let parseDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let dayYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d, yyyy"
        return formatter
    }()

    static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func startDate(for trip: TripCalendar) -> Date {
        parseDate(trip.startDate) ?? .distantFuture
    }

    static func dateRangeText(start: String, end: String) -> String {
        guard let startDate = parseDate(start), let endDate = parseDate(end) else {
            return "\(start)–\(end)"
        }

        let calendar = Calendar(identifier: .gregorian)
        if calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate) {
            let startText = monthDayFormatter.string(from: startDate)
            let endText = dayYearFormatter.string(from: endDate)
            return "\(startText)–\(endText)"
        }

        let startText = fullDateFormatter.string(from: startDate)
        let endText = fullDateFormatter.string(from: endDate)
        return "\(startText)–\(endText)"
    }

    static func daysToGoText(start: String) -> String {
        guard let startDate = parseDate(start) else {
            return "Dates to be announced"
        }

        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: startDate)
        let dayCount = max(calendar.dateComponents([.day], from: now, to: startDay).day ?? 0, 0)
        return dayCount == 1 ? "1 day to go" : "\(dayCount) days to go"
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = parseFormatter.date(from: value) {
            return date
        }
        return parseDateTimeFormatter.date(from: value)
    }
}
