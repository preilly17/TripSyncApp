import SwiftUI

struct ProposalsTabView: View {
    @StateObject private var viewModel: FlightProposalsViewModel
    @State private var alertInfo: AlertInfo?
    @State private var proposalToCancel: FlightProposal?

    init(tripId: Int, flightsAPI: FlightsAPI? = nil) {
        let resolvedAPI = flightsAPI ?? (try? FlightsAPI())
        _viewModel = StateObject(wrappedValue: FlightProposalsViewModel(tripId: tripId, flightsAPI: resolvedAPI))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Proposals")
                .font(.title3)
                .fontWeight(.semibold)

            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView("Loading proposals")
                        .frame(maxWidth: .infinity, minHeight: 120)
                case .empty:
                    ContentUnavailableView(
                        "No flight proposals yet",
                        systemImage: "airplane",
                        description: Text("Propose flights from the Flights tab to review them here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 160)
                case .loaded(let proposals):
                    LazyVStack(spacing: 12) {
                        ForEach(proposals) { proposal in
                            FlightProposalCard(
                                proposal: proposal,
                                isCanceling: viewModel.cancelingProposalId == proposal.id
                            ) {
                                proposalToCancel = proposal
                            }
                        }
                    }
                case .error(let message):
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Unable to load proposals")
                            .font(.headline)
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                }
            }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.loadProposals()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .confirmationDialog(
            "Cancel this proposal?",
            isPresented: Binding(
                get: { proposalToCancel != nil },
                set: { if !$0 { proposalToCancel = nil } }
            ),
            presenting: proposalToCancel
        ) { proposal in
            Button("Cancel Proposal", role: .destructive) {
                Task {
                    await cancelProposal(proposal)
                }
            }
        } message: { _ in
            Text("This will remove the proposal from the trip.")
        }
        .alert(item: $alertInfo) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
    }

    @MainActor
    private func cancelProposal(_ proposal: FlightProposal) async {
        do {
            try await viewModel.cancelProposal(proposalId: proposal.id)
            alertInfo = AlertInfo(
                title: "Proposal Canceled",
                message: "Your flight proposal was canceled."
            )
        } catch let error as APIError {
            let message: String
            switch error {
            case .httpStatus(let statusCode, _):
                message = "Status code: \(statusCode)."
            default:
                message = error.errorDescription ?? "Something went wrong while canceling the proposal."
            }
            alertInfo = AlertInfo(title: "Unable to Cancel", message: message)
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Cancel",
                message: error.localizedDescription
            )
        }
    }
}

@MainActor
final class FlightProposalsViewModel: ObservableObject {
    @Published var state: FlightProposalsState = .loading
    @Published var proposals: [FlightProposal] = []
    @Published var cancelingProposalId: Int?

    private let tripId: Int
    private let flightsAPI: FlightsAPI?

    init(tripId: Int, flightsAPI: FlightsAPI?) {
        self.tripId = tripId
        self.flightsAPI = flightsAPI
    }

    func loadProposals() async {
        guard let flightsAPI else {
            state = .error("Missing API configuration.")
            return
        }

        do {
            let proposals = try await flightsAPI.fetchFlightProposals(tripId: tripId)
            applyProposals(proposals)
        } catch let error as APIError {
            proposals = []
            state = .error(error.errorDescription ?? "Unable to load proposals.")
        } catch {
            proposals = []
            state = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        await loadProposals()
    }

    func cancelProposal(proposalId: Int) async throws {
        guard let flightsAPI else {
            throw APIError.invalidResponse
        }

        cancelingProposalId = proposalId
        defer { cancelingProposalId = nil }
        try await flightsAPI.cancelFlightProposal(proposalId: proposalId)

        removeProposal(withId: proposalId)
        Task {
            await loadProposals()
        }
    }

    private func removeProposal(withId proposalId: Int) {
        let updated = proposals.filter { $0.id != proposalId }
        applyProposals(updated)
    }

    private func applyProposals(_ proposals: [FlightProposal]) {
        let filtered = proposals.filter { !$0.isCanceled }
        self.proposals = filtered
        state = filtered.isEmpty ? .empty : .loaded(filtered)
    }
}

enum FlightProposalsState {
    case loading
    case empty
    case loaded([FlightProposal])
    case error(String)
}

private struct FlightProposalCard: View {
    let proposal: FlightProposal
    let isCanceling: Bool
    let onCancel: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(proposal.displayTitle)
                    .font(.headline)

                Text(routeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Depart → Arrive")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(timeRowValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if let pointsCost = proposal.pointsCost {
                Text("Points: \(pointsCost)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let proposedBy = proposal.proposedBy, !proposedBy.isEmpty {
                Text("Proposed by \(proposedBy)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if proposal.isCanceled {
                Text("Canceled")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray5))
                    )
            } else if proposal.canShowCancel {
                HStack {
                    Spacer()
                    Button {
                        onCancel()
                    } label: {
                        if isCanceling {
                            ProgressView()
                        } else {
                            Text("Cancel")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCanceling)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var routeText: String {
        let route = proposal.routeText
        return route.isEmpty ? "Route TBD" : route
    }

    private var timeRowValue: String {
        let departText = formattedDate(proposal.departDate, fallback: proposal.departDateTimeRaw)
        let arriveText = formattedDate(proposal.arriveDate, fallback: proposal.arriveDateTimeRaw)
        return "\(departText) → \(arriveText)"
    }

    private func formattedDate(_ date: Date?, fallback: String?) -> String {
        if let date {
            return Self.dateFormatter.string(from: date)
        }
        if let fallback, !fallback.isEmpty {
            return fallback
        }
        return "TBD"
    }
}

private struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    ProposalsTabView(tripId: 1, flightsAPI: nil)
        .padding()
}
