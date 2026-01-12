import Foundation

struct Flight: Identifiable, Codable {
    let flightId: Int?
    let airline: String?
    let flightNumber: String?
    let departAirportCode: String?
    let arriveAirportCode: String?
    let departDateTime: String?
    let arriveDateTime: String?
    let status: String?
    let bookingSource: String?

    var id: String {
        if let flightId {
            return String(flightId)
        }
        let airlineText = airline ?? ""
        let numberText = flightNumber ?? ""
        let departText = departDateTime ?? ""
        let arriveText = arriveDateTime ?? ""
        let routeText = "\(departAirportCode ?? "")-\(arriveAirportCode ?? "")"
        return [airlineText, numberText, routeText, departText, arriveText]
            .joined(separator: "|")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        let airlineText = airline?.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberText = flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [airlineText, numberText].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? "Flight" : parts.joined(separator: " ")
    }

    var subtitle: String {
        let route = routeText
        return route.isEmpty ? "Route TBD" : route
    }

    var routeText: String {
        let depart = departAirportCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let arrive = arriveAirportCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !depart.isEmpty || !arrive.isEmpty else { return "" }
        return "\(depart.isEmpty ? "—" : depart) → \(arrive.isEmpty ? "—" : arrive)"
    }

    var departDate: Date? {
        Flight.parseDate(from: departDateTime)
    }

    var arriveDate: Date? {
        Flight.parseDate(from: arriveDateTime)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func parseDate(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        return isoFallbackFormatter.date(from: value)
    }

    enum CodingKeys: String, CodingKey {
        case flightId = "id"
        case airline
        case flightNumber = "flight_number"
        case departAirportCode = "depart_airport_code"
        case arriveAirportCode = "arrive_airport_code"
        case departDateTime = "depart_datetime"
        case arriveDateTime = "arrive_datetime"
        case status
        case bookingSource = "booking_source"
    }
}
