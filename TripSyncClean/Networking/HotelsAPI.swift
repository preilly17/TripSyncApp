import Foundation

struct HotelsAPI {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    init() throws {
        self.client = try APIClient()
    }

    func fetchHotels(tripId: Int) async throws -> [Hotel] {
        let path = "/api/trips/\(tripId)/hotels"
        guard let url = URL(string: path, relativeTo: client.baseURL) else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await client.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
#if DEBUG
            print("HotelsAPI GET \(httpResponse.url?.absoluteString ?? path) -> \(httpResponse.statusCode)")
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }

            let decoder = makeDecoder()
            do {
                return try decoder.decode([Hotel].self, from: data)
            } catch {
                do {
                    let wrapped = try decoder.decode(HotelsResponse.self, from: data)
                    return wrapped.hotels
                } catch {
#if DEBUG
                    if let raw = String(data: data, encoding: .utf8) {
                        print("HotelsAPI decode failure. Raw JSON: \(raw)")
                    }
#endif
                    throw APIError.decoding(error)
                }
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    func addHotel(tripId: Int, payload: AddHotelPayload) async throws -> Hotel? {
        let path = "/api/trips/\(tripId)/hotels"
        let body = try encodedBody(payload, keyEncodingStrategy: .useDefaultKeys)
#if DEBUG
        if let json = String(data: body, encoding: .utf8) {
            print("🏨 HotelsAPI add payload: \(json)")
        }
#endif
        return try await sendRequest(path: path, method: "POST", body: body)
    }

    private func parseMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let dictionary = object as? [String: Any] {
            if let message = dictionary["message"] as? String {
                return message
            }
            if let error = dictionary["error"] as? String {
                return error
            }
        }
        return String(data: data, encoding: .utf8)
    }

    private func encodedBody<T: Encodable>(
        _ value: T,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToSnakeCase
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        return try encoder.encode(value)
    }

    private func sendRequest(path: String, method: String, body: Data?) async throws -> Hotel? {
        guard let url = URL(string: path, relativeTo: client.baseURL) else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await client.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
#if DEBUG
            let urlString = request.url?.absoluteString ?? "unknown URL"
            let method = request.httpMethod ?? "GET"
            print("HotelsAPI \(method) \(urlString) -> \(httpResponse.statusCode)")
            if !data.isEmpty, let raw = String(data: data, encoding: .utf8) {
                print("🏨 Hotels mutation raw response: \(raw)")
            }
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }

            guard !data.isEmpty else { return nil }
            let decoder = makeDecoder()
            if let hotel = try? decoder.decode(Hotel.self, from: data) {
                return hotel
            }
            if let wrapped = try? decoder.decode(HotelsResponse.self, from: data) {
                return wrapped.hotels.first
            }
#if DEBUG
            if let raw = String(data: data, encoding: .utf8) {
                print("HotelsAPI decode failure. Raw JSON: \(raw)")
            }
#endif
            throw APIError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid hotel response")))
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
        return decoder
    }
}

struct AddHotelPayload: Encodable {
    let name: String
    let address: String?
    let city: String?
    let checkIn: String?
    let checkOut: String?
    let bookingUrl: String?
    let status: String?
    let platform: String?

    init(
        name: String,
        address: String?,
        city: String?,
        checkIn: String?,
        checkOut: String?,
        bookingUrl: String?,
        status: String? = "confirmed",
        platform: String? = "manual"
    ) {
        self.name = name
        self.address = address
        self.city = city
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.bookingUrl = bookingUrl
        self.status = status
        self.platform = platform
    }
}

private struct HotelsResponse: Decodable {
    let hotels: [Hotel]
}
