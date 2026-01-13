import Foundation

struct Flight: Identifiable, Decodable {
    let id: Int
    let airline: String?
    let airlineCode: String?
    let flightNumber: String?
    let departAirportCode: String?
    let arriveAirportCode: String?
    let departAirportName: String?
    let arriveAirportName: String?
    let departDateTime: Date?
    let arriveDateTime: Date?
    let departDateTimeRaw: String?
    let arriveDateTimeRaw: String?
    let duration: String?
    let stops: Int?
    let price: String?
    let pointsCost: Int?
    let status: String?
    let platform: String?
    let bookingSource: String?

    var displayTitle: String {
        let airlineText = Self.firstNonEmpty([
            airline,
            airlineCode
        ])
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
        let depart = airportDisplay(code: departAirportCode, name: departAirportName)
        let arrive = airportDisplay(code: arriveAirportCode, name: arriveAirportName)
        guard !depart.isEmpty || !arrive.isEmpty else { return "" }
        return "\(depart.isEmpty ? "—" : depart) → \(arrive.isEmpty ? "—" : arrive)"
    }

    var departDate: Date? {
        departDateTime
    }

    var arriveDate: Date? {
        arriveDateTime
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

    private static func airportDisplay(code: String?, name: String?) -> String {
        let codeValue = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nameValue = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !codeValue.isEmpty { return codeValue }
        if let extracted = extractAirportCode(from: nameValue) {
            return extracted
        }
        return nameValue
    }

    private static func extractAirportCode(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let openParen = trimmed.lastIndex(of: "("),
           let closeParen = trimmed.lastIndex(of: ")"),
           openParen < closeParen {
            let codeRange = trimmed.index(after: openParen)..<closeParen
            let code = trimmed[codeRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !code.isEmpty {
                return code
            }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)

        let carrier = try? container.decodeIfPresent(Carrier.self, forKey: .carrier)
        let carrierName = carrier?.name ?? carrier?.code
        airline = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .airline),
            try? container.decodeIfPresent(String.self, forKey: .carrierName),
            carrierName
        ])
        airlineCode = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .airlineCode),
            carrier?.code
        ])

        flightNumber = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .flightNumber),
            try? container.decodeIfPresent(String.self, forKey: .number)
        ])

        let departAirport = Self.decodeAirport(
            from: container,
            keys: [.departAirportCode, .departureCode, .departureAirport, .origin, .from]
        )
        departAirportCode = departAirport.code
        departAirportName = departAirport.name

        let arriveAirport = Self.decodeAirport(
            from: container,
            keys: [.arriveAirportCode, .arrivalCode, .arrivalAirport, .destination, .to]
        )
        arriveAirportCode = arriveAirport.code
        arriveAirportName = arriveAirport.name

        let departDate = Self.decodeDate(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        let arriveDate = Self.decodeDate(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
        departDateTime = departDate
        arriveDateTime = arriveDate
        departDateTimeRaw = Self.decodeString(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        arriveDateTimeRaw = Self.decodeString(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])

        duration = Self.decodeDuration(from: container, key: .duration)
        stops = Self.decodeInt(from: container, key: .stops)
        price = Self.decodePrice(from: container, key: .price)
        pointsCost = Self.decodeInt(from: container, key: .pointsCost)

        status = try container.decodeIfPresent(String.self, forKey: .status)
        platform = try container.decodeIfPresent(String.self, forKey: .platform)
        bookingSource = try container.decodeIfPresent(String.self, forKey: .bookingSource)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case airline
        case airlineCode
        case carrier
        case carrierName = "carrier_name"
        case flightNumber = "flight_number"
        case number
        case departAirportCode = "depart_airport_code"
        case arriveAirportCode = "arrive_airport_code"
        case departureAirport
        case departureCode
        case arrivalAirport
        case arrivalCode
        case origin
        case destination
        case from
        case to
        case departDateTime = "depart_datetime"
        case arriveDateTime = "arrive_datetime"
        case departureDatetime = "departure_datetime"
        case arrivalDatetime = "arrival_datetime"
        case departureTime = "departure_time"
        case arrivalTime = "arrival_time"
        case duration
        case stops
        case price
        case pointsCost = "points_cost"
        case status
        case platform
        case bookingSource = "booking_source"
    }

    private struct Airport: Decodable {
        let code: String?
        let name: String?
    }

    private struct Carrier: Decodable {
        let name: String?
        let code: String?
    }

    private static func decodeAirport(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> (code: String?, name: String?) {
        for key in keys {
            if let airport = try? container.decodeIfPresent(Airport.self, forKey: key) {
                let code = airport.code?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = airport.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                if (code?.isEmpty == false) || (name?.isEmpty == false) {
                    return (code: code, name: name)
                }
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if trimmed.count == 3 {
                    return (code: trimmed, name: nil)
                } else {
                    return (code: nil, name: trimmed)
                }
            }
        }
        return (code: nil, name: nil)
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func decodeDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Date? {
        for key in keys {
            if let date = try? container.decodeIfPresent(Date.self, forKey: key) {
                return date
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                if let parsed = parseDate(from: value) {
                    return parsed
                }
            }
        }
        return nil
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

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
