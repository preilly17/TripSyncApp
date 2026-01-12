import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum State {
        case checking
        case unauthenticated
        case authenticated(User)
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
        await checkSession()
    }

    func checkSession() async {
        guard let authAPI else {
            state = .failed("Missing API configuration.")
            return
        }

        do {
            let user = try await authAPI.currentUser()
            state = .authenticated(user)
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                state = .unauthenticated
            default:
                state = .failed(error.errorDescription ?? "Unable to check session.")
            }
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
            let user = try await authAPI.login(usernameOrEmail: email, password: password)
            state = .authenticated(user)
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
}
