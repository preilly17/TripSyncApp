import Foundation

struct FlightsAPI {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    init() throws {
        self.client = try APIClient()
    }

    func fetchFlights(tripId: Int) async throws -> [Flight] {
        let path = "/api/trips/\(tripId)/flights"
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
            print("FlightsAPI GET \(httpResponse.url?.absoluteString ?? path) -> \(httpResponse.statusCode)")
            print("✈️ Flights request path:", url.path)
            if let raw = String(data: data, encoding: .utf8) {
                print("✈️ Flights raw response:", raw)
            }
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }

            let decoder = makeDecoder()
            do {
                let flights = try decoder.decode([Flight].self, from: data)
                logDecodedFlightSample(flights)
                return flights
            } catch {
                do {
                    let wrapped = try decoder.decode(FlightsResponse.self, from: data)
                    logDecodedFlightSample(wrapped.flights)
                    return wrapped.flights
                } catch {
#if DEBUG
                    if let raw = String(data: data, encoding: .utf8) {
                        print("FlightsAPI decode failure. Raw JSON: \(raw)")
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

    func addManualFlight(tripId: Int, payload: AddFlightPayload) async throws {
        let path = "/api/trips/\(tripId)/flights"
        let body = try encodedBody(payload, keyEncodingStrategy: .useDefaultKeys)
#if DEBUG
        if let json = String(data: body, encoding: .utf8) {
            print("✈️ FlightsAPI manual add payload:", json)
        }
#endif
        try await sendRequest(path: path, method: "POST", body: body)
    }

    func proposeFlight(tripId: Int, flightId: Int) async throws {
        let path = "/api/trips/\(tripId)/proposals/flights"
        let body = try encodedBody(
            ProposeFlightRequest(flightId: flightId),
            keyEncodingStrategy: .useDefaultKeys
        )
#if DEBUG
        if let json = String(data: body, encoding: .utf8) {
            print("✈️ Propose flight payload:", json)
        }
#endif
        try await sendRequest(path: path, method: "POST", body: body)
    }

    func cancelFlightProposal(tripId: Int, proposalId: Int) async throws {
        let path = "/api/trips/\(tripId)/proposals/\(proposalId)"
        try await sendCancellationRequest(path: path, method: "DELETE", body: nil)
    }

    func fetchFlightProposals(tripId: Int) async throws -> [FlightProposal] {
        let preferredPath = "/api/trips/\(tripId)/proposals/flights"
        do {
            return try await fetchProposals(path: preferredPath)
        } catch let error as APIError {
            if case .httpStatus(let statusCode, _) = error, statusCode == 404 || statusCode == 405 {
                let fallbackPath = "/api/trips/\(tripId)/proposals"
                let proposals = try await fetchProposals(path: fallbackPath)
                return proposals.filter { $0.isFlightProposal }
            }
            throw error
        } catch {
            throw error
        }
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

    private func sendRequest(path: String, method: String, body: Data?) async throws {
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
            print("FlightsAPI \(method) \(urlString) -> \(httpResponse.statusCode)")
            if !data.isEmpty, let raw = String(data: data, encoding: .utf8) {
                print("✈️ Flights mutation raw response:", raw)
            }
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func sendCancellationRequest(path: String, method: String, body: Data?) async throws {
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
            print("FlightsAPI \(method) \(urlString) -> \(httpResponse.statusCode)")
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = cancellationErrorMessage(from: data, response: httpResponse)
                throw APIError.httpStatus(httpResponse.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    private func cancellationErrorMessage(from data: Data, response: HTTPURLResponse) -> String? {
        guard !data.isEmpty else { return nil }
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        let isJSON = contentType.contains("application/json") || contentType.contains("application/problem+json")
        if isJSON {
            return parseMessage(from: data)
        }
#if DEBUG
        if let raw = String(data: data, encoding: .utf8) {
            print("✈️ FlightsAPI cancel non-JSON response:", raw)
        }
#endif
        return nil
    }

    private func fetchProposals(path: String) async throws -> [FlightProposal] {
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
            print("FlightsAPI GET \(httpResponse.url?.absoluteString ?? path) -> \(httpResponse.statusCode)")
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }

            let decoder = makeDecoder()
            do {
                return try decoder.decode([FlightProposal].self, from: data)
            } catch {
                let wrapped = try decoder.decode(FlightProposalsResponse.self, from: data)
                return wrapped.proposals
            }
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

    private func logDecodedFlightSample(_ flights: [Flight]) {
#if DEBUG
        guard let sample = flights.first else { return }
        let airline = sample.airline ?? "Unknown Airline"
        print("✈️ Decoded flight sample id=\(sample.id), airline=\(airline)")
#endif
    }
}

private struct FlightsResponse: Decodable {
    let flights: [Flight]
}

private struct FlightProposalsResponse: Decodable {
    let proposals: [FlightProposal]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let proposals = try? container.decode([FlightProposal].self, forKey: .proposals) {
            self.proposals = proposals
            return
        }
        if let proposals = try? container.decode([FlightProposal].self, forKey: .flightProposals) {
            self.proposals = proposals
            return
        }
        if let proposals = try? container.decode([FlightProposal].self, forKey: .flights) {
            self.proposals = proposals
            return
        }
        throw DecodingError.dataCorruptedError(forKey: .proposals, in: container, debugDescription: "Missing proposals list.")
    }

    private enum CodingKeys: String, CodingKey {
        case proposals
        case flightProposals
        case flights
    }
}

struct AddFlightPayload: Encodable {
    let airline: String
    let flightNumber: String
    let airlineCode: String
    let departureAirport: String
    let departureCode: String
    let departureTime: String
    let arrivalAirport: String
    let arrivalCode: String
    let arrivalTime: String
    let flightType: String
    let pointsCost: Int?

    enum CodingKeys: String, CodingKey {
        case airline
        case flightNumber
        case airlineCode
        case departureAirport
        case departureCode
        case departureTime
        case arrivalAirport
        case arrivalCode
        case arrivalTime
        case flightType
        case pointsCost = "points_cost"
    }
}

private struct ProposeFlightRequest: Encodable {
    let flightId: Int
}

/*
 Expected response shape (example):
 [
   {
     "id": 123,
     "airline": "Delta",
     "flight_number": "DL123",
     "depart_airport_code": "ATL",
     "arrive_airport_code": "AMS",
     "depart_datetime": "2025-03-01T09:00:00Z",
     "arrive_datetime": "2025-03-01T18:30:00Z",
     "status": "On time",
     "booking_source": "Manual"
   }
 ]
*/
