import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum State {
        case checking
        case unauthenticated
        case authenticated
        case failed(String)
    }

    @Published private(set) var state: State = .checking
    @Published var loginError: String?
    @Published var isAuthenticating = false

    private let authAPI: AuthAPI?
    let tripsAPI: TripsAPI?

    init(client: APIClient? = try? APIClient()) {
        self.authAPI = client.map(AuthAPI.init)
        self.tripsAPI = client.map(TripsAPI.init)
        if client == nil {
            state = .failed("Missing API configuration.")
        }
    }

    func checkSessionIfNeeded() async {
        guard case .checking = state else { return }
        guard !hasCheckedSession else { return }
        hasCheckedSession = true
        await checkSession()
    }

    func checkSession() async {
        guard let authAPI else {
            state = .failed("Missing API configuration.")
            return
        }

        do {
            let isAuthenticated = try await authAPI.checkSessionViaTrips()
            state = isAuthenticated ? .authenticated : .unauthenticated
        } catch let error as APIError {
            state = .failed(error.errorDescription ?? "Unable to check session.")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func login(email: String, password: String) async {
        guard let authAPI else {
            loginError = "Missing API configuration."
            return
        }

        isAuthenticating = true
        loginError = nil
        defer { isAuthenticating = false }

        do {
            try await authAPI.login(usernameOrEmail: email, password: password)
            let isAuthenticated = try await authAPI.checkSessionViaTrips()
            state = isAuthenticated ? .authenticated : .unauthenticated
        } catch {
            loginError = errorMessage(for: error)
        }
    }

    func retrySessionCheck() async {
        state = .checking
        await checkSession()
    }

    private func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.errorDescription ?? "Something went wrong."
        }
        return error.localizedDescription
    }

    private var hasCheckedSession = false
}
