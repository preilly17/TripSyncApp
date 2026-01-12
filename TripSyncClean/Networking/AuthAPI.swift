import Foundation

struct AuthAPI {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    init() throws {
        self.client = try APIClient()
    }

    func login(usernameOrEmail: String, password: String) async throws {
        let payload = LoginRequest(usernameOrEmail: usernameOrEmail, password: password)
        let body = try JSONEncoder().encode(payload)
        let path = "/api/auth/login"
        guard let url = URL(string: path, relativeTo: client.baseURL) else {
            throw APIError.invalidURL(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Cookie-based auth: the server sets a session cookie and may return an empty body.
        do {
            let (data, response) = try await client.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
#if DEBUG
            print("AuthAPI POST \(httpResponse.url?.absoluteString ?? path) -> \(httpResponse.statusCode)")
#endif
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = responseSnippet(from: data)
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized(message)
                }
                throw APIError.httpStatus(httpResponse.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    func currentUser() async throws -> User {
        try await client.request("/api/auth/me")
    }

    func checkSessionViaTrips() async throws -> Bool {
        let path = "/api/trips"
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
            print("AuthAPI GET \(httpResponse.url?.absoluteString ?? path) -> \(httpResponse.statusCode)")
#endif
            switch httpResponse.statusCode {
            case 200:
                return true
            case 401:
                return false
            default:
                throw APIError.httpStatus(httpResponse.statusCode, responseSnippet(from: data))
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    func logout() async throws {
        _ = try await client.request(
            "/api/auth/logout",
            method: "POST",
            body: nil
        ) as EmptyResponse
    }
}

private struct LoginRequest: Encodable {
    let usernameOrEmail: String
    let password: String
}

private func responseSnippet(from data: Data) -> String? {
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
    if let string = String(data: data, encoding: .utf8) {
        let snippet = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return snippet.isEmpty ? nil : String(snippet.prefix(200))
    }
    return nil
}
