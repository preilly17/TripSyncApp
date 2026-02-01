import Foundation

enum FlightDateFormatter {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func dateString(from date: Date?) -> String? {
        guard let date else { return nil }
        return dateFormatter.string(from: date)
    }

    static func timeString(from date: Date?) -> String? {
        guard let date else { return nil }
        return timeFormatter.string(from: date)
    }

    static func dateTimeString(from date: Date?) -> String? {
        guard let date else { return nil }
        return dateTimeFormatter.string(from: date)
    }
}
