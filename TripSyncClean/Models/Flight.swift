import Foundation

struct Flight: Identifiable, Decodable {
    let id: Int
    let airline: String?
    let flightNumber: String?
    let departureAirport: String?
    let departureCode: String?
    let departureTimeRaw: String?
    let arrivalAirport: String?
    let arrivalCode: String?
    let arrivalTimeRaw: String?
    let duration: String?
    let stops: Int?
    let price: String?
    let pointsCost: Int?
    let currency: String?
    let status: String?
    let bookingUrl: String?
    let platform: String?
    let seatClass: String?
    let proposer: String?

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
        routeText
    }

    var routeText: String {
        let departure = routeCode(preferred: departureCode, fallback: departureAirport)
        let arrival = routeCode(preferred: arrivalCode, fallback: arrivalAirport)
        if departure.isEmpty && arrival.isEmpty {
            return "TBD"
        }
        let departureText = departure.isEmpty ? "TBD" : departure
        let arrivalText = arrival.isEmpty ? "TBD" : arrival
        return "\(departureText) → \(arrivalText)"
    }

    var departureDate: Date? {
        Self.parseDate(from: departureTimeRaw)
    }

    var arrivalDate: Date? {
        Self.parseDate(from: arrivalTimeRaw)
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

    private static var hasLoggedDecode = false

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        airline = Self.decodeString(from: container, key: .airline)
        flightNumber = Self.decodeString(from: container, key: .flightNumber)
        departureAirport = Self.decodeString(from: container, key: .departureAirport)
        departureCode = Self.decodeString(from: container, key: .departureCode)
        departureTimeRaw = Self.decodeString(from: container, key: .departureTimeRaw)
        arrivalAirport = Self.decodeString(from: container, key: .arrivalAirport)
        arrivalCode = Self.decodeString(from: container, key: .arrivalCode)
        arrivalTimeRaw = Self.decodeString(from: container, key: .arrivalTimeRaw)
        duration = Self.decodeDuration(from: container, key: .duration)
        stops = Self.decodeInt(from: container, key: .stops)
        price = Self.decodePrice(from: container, key: .price)
        pointsCost = Self.decodeInt(from: container, key: .pointsCost)
        currency = Self.decodeString(from: container, key: .currency)
        status = Self.decodeString(from: container, key: .status)
        bookingUrl = Self.decodeString(from: container, key: .bookingUrl)
        platform = Self.decodeString(from: container, key: .platform)
        seatClass = Self.decodeString(from: container, key: .seatClass)
        proposer = Self.decodeString(from: container, key: .proposer)

        #if DEBUG
        if !Self.hasLoggedDecode {
            Self.hasLoggedDecode = true
            let departureParsed = departureDate != nil
            let arrivalParsed = arrivalDate != nil
            print(
                "DEBUG Flight decode: departureTimeRaw=\(departureTimeRaw ?? "nil"), arrivalTimeRaw=\(arrivalTimeRaw ?? "nil"), departureParsed=\(departureParsed), arrivalParsed=\(arrivalParsed)"
            )
        }
        #endif
    }

    enum CodingKeys: String, CodingKey {
        case id
        case airline
        case flightNumber
        case departureAirport
        case departureCode
        case departureTimeRaw = "departureTime"
        case arrivalAirport
        case arrivalCode
        case arrivalTimeRaw = "arrivalTime"
        case duration
        case stops
        case price
        case pointsCost
        case currency
        case status
        case bookingUrl
        case platform
        case seatClass
        case proposer
    }

    private static func parseDate(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        return isoFallbackFormatter.date(from: value)
    }

    private static func routeCode(preferred code: String?, fallback airport: String?) -> String {
        let codeValue = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !codeValue.isEmpty {
            return codeValue
        }
        if let extracted = extractAirportCode(from: airport) {
            return extracted
        }
        return ""
    }

    private static func extractAirportCode(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let openParen = trimmed.lastIndex(of: "("),
              let closeParen = trimmed.lastIndex(of: ")"),
              openParen < closeParen else {
            return nil
        }
        let codeRange = trimmed.index(after: openParen)..<closeParen
        let code = trimmed[codeRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : code
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        guard let value = try? container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(trimmed)
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }

    private static func decodeDuration(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return formatDuration(minutes: intValue)
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let numeric = Int(trimmed) {
                return formatDuration(minutes: numeric)
            }
            return trimmed.isEmpty ? nil : trimmed
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return formatDuration(minutes: Int(doubleValue))
        }
        return nil
    }

    private static func formatDuration(minutes: Int) -> String {
        guard minutes > 0 else { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(mins)m"
    }

    private static func decodePrice(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return formatPrice(doubleValue)
        }
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return formatPrice(Double(intValue))
        }
        return nil
    }

    private static func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        if let formatted = formatter.string(from: NSNumber(value: value)) {
            return formatted
        }
        return String(format: "%.2f", value)
    }
}
