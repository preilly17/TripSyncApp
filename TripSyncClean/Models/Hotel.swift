import Foundation

struct Hotel: Identifiable, Decodable, Hashable {
    let id: Int
    let tripId: Int?
    let name: String?
    let city: String?
    let address: String?
    let checkInRaw: String?
    let checkOutRaw: String?
    let bookingUrl: String?
    let status: String?
    let platform: String?
    let confirmationNumber: String?
    let notes: String?

    var checkIn: Date? {
        Self.parseDate(from: checkInRaw)
    }

    var checkOut: Date? {
        Self.parseDate(from: checkOutRaw)
    }

    var displayTitle: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? "Hotel" : trimmedName
    }

    var dateRangeText: String {
        let checkInDate = checkIn
        let checkOutDate = checkOut

        if let checkInDate, let checkOutDate {
            return "\(Self.dateFormatter.string(from: checkInDate)) – \(Self.dateFormatter.string(from: checkOutDate))"
        }

        if let checkInDate {
            return "Check-in \(Self.dateFormatter.string(from: checkInDate))"
        }

        if let checkOutDate {
            return "Check-out \(Self.dateFormatter.string(from: checkOutDate))"
        }

        return "Dates TBD"
    }

    var locationText: String {
        let trimmedCity = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedAddress = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch (trimmedCity.isEmpty, trimmedAddress.isEmpty) {
        case (false, false):
            return "\(trimmedCity) • \(trimmedAddress)"
        case (false, true):
            return trimmedCity
        case (true, false):
            return trimmedAddress
        default:
            return "Location TBD"
        }
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let resolvedId = Self.decodeInt(from: container, key: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing id")
        }
        id = resolvedId
        tripId = Self.decodeInt(from: container, key: .tripId)
        name = Self.decodeString(from: container, key: .name)
        city = Self.decodeString(from: container, key: .city)
        address = Self.decodeString(from: container, key: .address)
        checkInRaw = Self.decodeString(from: container, key: .checkInRaw)
        checkOutRaw = Self.decodeString(from: container, key: .checkOutRaw)
        bookingUrl = Self.decodeString(from: container, key: .bookingUrl)
        status = Self.decodeString(from: container, key: .status)
        platform = Self.decodeString(from: container, key: .platform)
        confirmationNumber = Self.decodeString(from: container, key: .confirmationNumber)
        notes = Self.decodeString(from: container, key: .notes)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tripId
        case name
        case city
        case address
        case checkInRaw = "checkIn"
        case checkOutRaw = "checkOut"
        case bookingUrl
        case status
        case platform
        case confirmationNumber
        case notes
    }

    private static func parseDate(from value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        return isoFallbackFormatter.date(from: value)
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

    static func == (lhs: Hotel, rhs: Hotel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
