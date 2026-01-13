import Foundation

struct FlightProposal: Identifiable, Decodable {
    let id: Int
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
    let pointsCost: Int?
    let proposedBy: String?
    let canCancel: Bool?
    let status: String?

    var displayTitle: String {
        let airlineText = airline?.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberText = flightNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [airlineText, numberText].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? "Flight Proposal" : parts.joined(separator: " ")
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

    var normalizedStatus: String? {
        status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var isCanceled: Bool {
        guard let normalizedStatus else { return false }
        return normalizedStatus == "canceled" || normalizedStatus == "cancelled"
    }

    var isActive: Bool {
        guard let normalizedStatus else { return true }
        return normalizedStatus == "active"
    }

    var isFlightProposal: Bool {
        flightId != nil
            || hasText(airline)
            || hasText(flightNumber)
            || hasText(departAirportCode)
            || hasText(arriveAirportCode)
            || hasText(departAirportName)
            || hasText(arriveAirportName)
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

        id = try container.decode(Int.self, forKey: .id)
        flightId = try? container.decodeIfPresent(Int.self, forKey: .flightId)

        let nestedFlight = try? container.decodeIfPresent(Flight.self, forKey: .flight)

        airline = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .airline),
            try? container.decodeIfPresent(String.self, forKey: .carrierName),
            nestedFlight?.airline
        ])

        flightNumber = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .flightNumber),
            try? container.decodeIfPresent(String.self, forKey: .number),
            nestedFlight?.flightNumber
        ])

        let departAirport = Self.decodeAirport(from: container, keys: [.departAirportCode, .origin, .from])
        let arriveAirport = Self.decodeAirport(from: container, keys: [.arriveAirportCode, .destination, .to])

        departAirportCode = departAirport.code ?? nestedFlight?.departAirportCode
        departAirportName = departAirport.name ?? nestedFlight?.departAirportName
        arriveAirportCode = arriveAirport.code ?? nestedFlight?.arriveAirportCode
        arriveAirportName = arriveAirport.name ?? nestedFlight?.arriveAirportName

        let departDate = Self.decodeDate(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        let arriveDate = Self.decodeDate(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
        departDateTime = departDate ?? nestedFlight?.departDateTime
        arriveDateTime = arriveDate ?? nestedFlight?.arriveDateTime
        departDateTimeRaw = Self.decodeString(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
            ?? nestedFlight?.departDateTimeRaw
        arriveDateTimeRaw = Self.decodeString(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
            ?? nestedFlight?.arriveDateTimeRaw

        pointsCost = Self.decodePoints(from: container, key: .pointsCost)

        proposedBy = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .proposedBy),
            try? container.decodeIfPresent(String.self, forKey: .proposedByName),
            try? container.decodeIfPresent(String.self, forKey: .createdBy),
            try? container.decodeIfPresent(String.self, forKey: .proposer),
            Self.decodeUserName(from: container, key: .proposedByUser),
            Self.decodeUserName(from: container, key: .user)
        ])

        canCancel = try? container.decodeIfPresent(Bool.self, forKey: .canCancel)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case flightId
        case flight
        case airline
        case carrierName
        case flightNumber
        case number
        case departAirportCode
        case arriveAirportCode
        case origin
        case destination
        case from
        case to
        case departDateTime
        case arriveDateTime
        case departureDatetime
        case arrivalDatetime
        case departureTime
        case arrivalTime
        case pointsCost
        case proposedBy
        case proposedByName
        case createdBy
        case proposer
        case proposedByUser
        case user
        case canCancel
        case status
    }

    private struct ProposedUser: Decodable {
        let name: String?
        let username: String?
        let firstName: String?
        let lastName: String?
        let email: String?
    }

    private static func decodeUserName(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        guard let user = try? container.decodeIfPresent(ProposedUser.self, forKey: key) else {
            return nil
        }

        if let name = user.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        let combined = [user.firstName, user.lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !combined.isEmpty {
            return combined
        }
        if let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return username
        }
        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return nil
    }

    private static func decodePoints(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(value)
        }
        return nil
    }

    private static func decodeAirport(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> (code: String?, name: String?) {
        for key in keys {
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

    private func hasText(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
