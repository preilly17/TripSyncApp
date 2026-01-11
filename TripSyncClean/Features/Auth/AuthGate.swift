import SwiftUI

struct AuthGate: View {
    @State private var state: AuthState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Checking session...")
            case .unauthenticated:
                LoginView { user in
                    state = .authenticated(user)
                }
            case .authenticated(let user):
                NavigationStack {
                    TripsListView(user: user)
                }
            case .error(let message):
                VStack(spacing: 16) {
                    Text("Unable to load session")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        state = .loading
                        Task {
                            await loadCurrentUser()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .task {
            if case .loading = state {
                await loadCurrentUser()
            }
        }
    }

    private func loadCurrentUser() async {
        do {
            let api = try AuthAPI()
            let user = try await api.currentUser()
            state = .authenticated(user)
        } catch let error as APIError {
            switch error {
            case .unauthorized:
                state = .unauthenticated
            default:
                state = .error(error.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

private enum AuthState {
    case loading
    case unauthenticated
    case authenticated(User)
    case error(String)
}

#Preview {
    AuthGate()
}
