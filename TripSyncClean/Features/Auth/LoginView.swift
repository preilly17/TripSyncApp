import SwiftUI

struct LoginView: View {
    let onLoginSuccess: (User) -> Void

    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Welcome Back")
                    .font(.title)
                Text("Sign in to access your trips.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                TextField("Username or Email", text: $usernameOrEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await signIn()
                }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || usernameOrEmail.isEmpty || password.isEmpty)
        }
        .padding()
    }

    private func signIn() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let api = try AuthAPI()
            let user = try await api.login(usernameOrEmail: usernameOrEmail, password: password)
            onLoginSuccess(user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    LoginView { _ in }
}
