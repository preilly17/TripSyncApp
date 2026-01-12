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
#endif
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }

            let decoder = JSONDecoder()
            do {
                return try decoder.decode([Flight].self, from: data)
            } catch {
                do {
                    let wrapped = try decoder.decode(FlightsResponse.self, from: data)
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
}

private struct FlightsResponse: Decodable {
    let flights: [Flight]
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
