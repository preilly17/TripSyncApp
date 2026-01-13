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
    private let proposerProfile: ProposedUser?
    let canCancel: Bool?
    let status: String?
    var rankings: [FlightProposalRanking]
    var currentUserRanking: FlightProposalRanking?
    var averageRanking: Double?
    private let permissions: Permissions?

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

    var canShowCancel: Bool {
        canCancel == true && !isCanceled
    }

    var displayAverageRanking: Double? {
        averageRanking ?? computedAverageRanking
    }

    func proposerDisplayName(currentUser: User?) -> String? {
        if let currentUser, isProposedByCurrentUser(currentUser) {
            return "you"
        }

        if let name = proposerProfile?.displayName {
            return name
        }

        return sanitizedProposedBy
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
        if let extracted = extractAirportCode(from: nameValue) {
            return extracted
        }
        return nameValue
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

        departAirportCode = departAirport.code ?? nestedFlight?.departureCode
        departAirportName = departAirport.name ?? nestedFlight?.departureAirport
        arriveAirportCode = arriveAirport.code ?? nestedFlight?.arrivalCode
        arriveAirportName = arriveAirport.name ?? nestedFlight?.arrivalAirport

        let departDate = Self.decodeDate(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
        let arriveDate = Self.decodeDate(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
        departDateTime = departDate ?? nestedFlight?.departureDate
        arriveDateTime = arriveDate ?? nestedFlight?.arrivalDate
        departDateTimeRaw = Self.decodeString(from: container, keys: [.departDateTime, .departureDatetime, .departureTime])
            ?? nestedFlight?.departureTimeRaw
        arriveDateTimeRaw = Self.decodeString(from: container, keys: [.arriveDateTime, .arrivalDatetime, .arrivalTime])
            ?? nestedFlight?.arrivalTimeRaw

        pointsCost = Self.decodePoints(from: container, key: .pointsCost)

        proposedBy = Self.firstNonEmpty([
            try? container.decodeIfPresent(String.self, forKey: .proposedBy),
            try? container.decodeIfPresent(String.self, forKey: .proposedByName),
            try? container.decodeIfPresent(String.self, forKey: .createdBy),
            try? container.decodeIfPresent(String.self, forKey: .proposer),
            Self.decodeUserName(from: container, key: .proposedByUser),
            Self.decodeUserName(from: container, key: .user)
        ])

        proposerProfile = Self.decodeProposer(from: container)

        permissions = try? container.decodeIfPresent(Permissions.self, forKey: .permissions)
        canCancel = permissions?.canCancel ?? (try? container.decodeIfPresent(Bool.self, forKey: .canCancel))
        status = try? container.decodeIfPresent(String.self, forKey: .status)

        rankings = (try? container.decodeIfPresent([FlightProposalRanking].self, forKey: .rankings)) ?? []
        currentUserRanking = Self.decodeCurrentUserRanking(from: container)
        averageRanking = Self.decodeDouble(from: container, keys: [.averageRanking, .avgRanking, .averageRank])
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
        case permissions
        case rankings
        case currentUserRanking
        case averageRanking
        case avgRanking
        case averageRank
    }

    private struct Permissions: Decodable {
        let canCancel: Bool?
    }

    private struct ProposedUser: Decodable {
        let name: String?
        let username: String?
        let firstName: String?
        let lastName: String?
        let email: String?

        var displayName: String? {
            let combined = [firstName, lastName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !combined.isEmpty {
                return combined
            }
            if let username = username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
                return username
            }
            return nil
        }
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

    private static func decodeProposer(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> ProposedUser? {
        if let proposer = try? container.decodeIfPresent(ProposedUser.self, forKey: .proposer) {
            return proposer
        }
        if let proposer = try? container.decodeIfPresent(ProposedUser.self, forKey: .proposedByUser) {
            return proposer
        }
        if let proposer = try? container.decodeIfPresent(ProposedUser.self, forKey: .user) {
            return proposer
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

    private static func decodeDouble(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> Double? {
        for key in keys {
            if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? container.decodeIfPresent(String.self, forKey: key) {
                return Double(value)
            }
        }
        return nil
    }

    private static func decodeCurrentUserRanking(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> FlightProposalRanking? {
        if let ranking = try? container.decodeIfPresent(FlightProposalRanking.self, forKey: .currentUserRanking) {
            return ranking
        }
        if let rankValue = try? container.decodeIfPresent(Int.self, forKey: .currentUserRanking) {
            return FlightProposalRanking(id: nil, rank: rankValue, userId: nil, userName: nil)
        }
        if let rankValue = try? container.decodeIfPresent(String.self, forKey: .currentUserRanking),
           let rank = Int(rankValue) {
            return FlightProposalRanking(id: nil, rank: rank, userId: nil, userName: nil)
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

    private var computedAverageRanking: Double? {
        guard !rankings.isEmpty else { return nil }
        let total = rankings.reduce(0) { $0 + $1.rank }
        return Double(total) / Double(rankings.count)
    }

    private var sanitizedProposedBy: String? {
        guard let proposedBy else { return nil }
        let trimmed = proposedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("@") {
            return nil
        }
        if trimmed.contains("|") {
            return nil
        }
        if trimmed.lowercased().hasPrefix("user_") {
            return nil
        }
        if UUID(uuidString: trimmed) != nil {
            return nil
        }
        return trimmed
    }

    private func isProposedByCurrentUser(_ currentUser: User) -> Bool {
        if let proposerEmail = proposerProfile?.email?.lowercased(),
           proposerEmail == currentUser.email.lowercased() {
            return true
        }

        if let proposerUsername = proposerProfile?.username?.lowercased(),
           let username = currentUser.username?.lowercased(),
           proposerUsername == username {
            return true
        }

        if let proposedBy = proposedBy?.lowercased(),
           let username = currentUser.username?.lowercased(),
           proposedBy == username {
            return true
        }

        if let proposedBy = proposedBy?.lowercased(),
           proposedBy == currentUser.email.lowercased() {
            return true
        }

        return false
    }
}

struct FlightProposalRanking: Decodable, Equatable {
    let id: Int?
    let rank: Int
    let userId: Int?
    let userName: String?

    init(id: Int?, rank: Int, userId: Int?, userName: String?) {
        self.id = id
        self.rank = rank
        self.userId = userId
        self.userName = userName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(Int.self, forKey: .id)

        if let rankValue = try? container.decodeIfPresent(Int.self, forKey: .rank) {
            rank = rankValue
        } else if let rankValue = try? container.decodeIfPresent(Int.self, forKey: .ranking) {
            rank = rankValue
        } else if let rankValue = try? container.decodeIfPresent(Int.self, forKey: .position) {
            rank = rankValue
        } else if let rankValue = try? container.decodeIfPresent(String.self, forKey: .rank),
                  let parsed = Int(rankValue) {
            rank = parsed
        } else if let rankValue = try? container.decodeIfPresent(String.self, forKey: .ranking),
                  let parsed = Int(rankValue) {
            rank = parsed
        } else if let rankValue = try? container.decodeIfPresent(String.self, forKey: .position),
                  let parsed = Int(rankValue) {
            rank = parsed
        } else {
            throw DecodingError.dataCorruptedError(forKey: .rank, in: container, debugDescription: "Missing rank.")
        }

        userId = try? container.decodeIfPresent(Int.self, forKey: .userId)
        userName = try? container.decodeIfPresent(String.self, forKey: .userName)
    }

    func updating(rank: Int) -> FlightProposalRanking {
        FlightProposalRanking(id: id, rank: rank, userId: userId, userName: userName)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rank
        case ranking
        case position
        case userId
        case userName
    }
}
