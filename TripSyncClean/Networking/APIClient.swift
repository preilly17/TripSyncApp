import Foundation

struct EmptyResponse: Decodable {}

struct APIClient {
    let session: URLSession
    let baseURL: URL

    init(session: URLSession = .shared) throws {
        let key = "API_BASE_URL"
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !baseURLString.isEmpty else {
            throw APIError.missingConfiguration(key)
        }
        guard let baseURL = URL(string: baseURLString) else {
            throw APIError.invalidBaseURL(baseURLString)
        }
        self.session = session
        self.baseURL = baseURL
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized(parseMessage(from: data))
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode, parseMessage(from: data))
            }
            if data.isEmpty, T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
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
