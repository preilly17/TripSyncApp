import Foundation

struct AuthAPI {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    init() throws {
        self.client = try APIClient()
    }

    func login(usernameOrEmail: String, password: String) async throws -> User {
        let payload = LoginRequest(usernameOrEmail: usernameOrEmail, password: password)
        let body = try JSONEncoder().encode(payload)
        return try await client.request(
            "/api/auth/login",
            method: "POST",
            body: body,
            headers: ["Content-Type": "application/json"]
        )
    }

    func currentUser() async throws -> User {
        try await client.request("/api/auth/user")
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
