import Foundation

struct Flight: Identifiable, Decodable {
    let flightId: Int?
    let airline: String?
    let flightNumber: String?
    let departAirportCode: String?
    let arriveAirportCode: String?
    let departAirportName: String?
    let arriveAirportName: String?
    let departDateTime: Date?
    let arriveDateTime: Date?
    let departDateTimeRaw: String?
    let arriveDateTimeRaw: String?
    let status: String?
    let bookingSource: String?

    var id: String {
        if let flightId {
            return String(flightId)
        }
        let airlineText = airline ?? ""
        let numberText = flightNumber ?? ""
        let departText = departDateTimeRaw ?? ""
        let arriveText = arriveDateTimeRaw ?? ""
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
        return nameValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        flightId = try container.decodeIfPresent(Int.self, forKey: .id)

        let carrier = try? container.decodeIfPresent(Carrier.self, forKey: .carrier)
        let carrierName = carrier?.name ?? carrier?.code
        airline = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .airline),
            try? container.decodeIfPresent(String.self, forKey: .carrierName),
            carrierName
        ])

        flightNumber = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .flightNumber),
            try? container.decodeIfPresent(String.self, forKey: .number)
        ])

        let departAirport = Self.decodeAirport(from: container, keys: [.departAirportCode, .origin, .from])
        departAirportCode = departAirport.code
        departAirportName = departAirport.name

        let arriveAirport = Self.decodeAirport(from: container, keys: [.arriveAirportCode, .destination, .to])
        arriveAirportCode = arriveAirport.code
        arriveAirportName = arriveAirport.name

        let departDate = Self.decodeDate(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        let arriveDate = Self.decodeDate(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
        departDateTime = departDate
        arriveDateTime = arriveDate
        departDateTimeRaw = Self.decodeString(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        arriveDateTimeRaw = Self.decodeString(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])

        status = try container.decodeIfPresent(String.self, forKey: .status)
        bookingSource = try container.decodeIfPresent(String.self, forKey: .bookingSource)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case airline
        case carrier
        case carrierName = "carrier_name"
        case flightNumber = "flight_number"
        case number
        case departAirportCode = "depart_airport_code"
        case arriveAirportCode = "arrive_airport_code"
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
        case status
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

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}
