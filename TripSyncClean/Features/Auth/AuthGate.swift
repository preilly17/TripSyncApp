import SwiftUI

struct AuthGate: View {
    @StateObject private var viewModel: AuthViewModel

    init(client: APIClient? = try? APIClient()) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            content
        }
        .task {
            await viewModel.checkSessionIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .checking:
            ProgressView("Checking session")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unauthenticated:
            LoginView(viewModel: viewModel)
        case .authenticated:
            TripsListView(tripsAPI: viewModel.tripsAPI)
        case .failed(let message):
            VStack(spacing: 16) {
                Text("Unable to connect")
                    .font(.title2)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await viewModel.retrySessionCheck()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    AuthGate(client: nil)
}
