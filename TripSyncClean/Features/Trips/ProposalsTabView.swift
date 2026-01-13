import SwiftUI

struct ProposalsTabView: View {
    @StateObject private var viewModel: FlightProposalsViewModel
    @State private var alertInfo: AlertInfo?
    @State private var proposalToCancel: FlightProposal?
    @State private var proposalToVote: FlightProposal?

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
                                isCanceling: viewModel.cancelingProposalId == proposal.id,
                                onVote: { proposalToVote = proposal }
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
        .confirmationDialog(
            "Vote on this proposal",
            isPresented: Binding(
                get: { proposalToVote != nil },
                set: { if !$0 { proposalToVote = nil } }
            ),
            presenting: proposalToVote
        ) { proposal in
            Button("1st Choice") {
                Task { await submitVote(proposal, ranking: 1) }
            }
            Button("2nd Choice") {
                Task { await submitVote(proposal, ranking: 2) }
            }
            Button("3rd Choice") {
                Task { await submitVote(proposal, ranking: 3) }
            }
            Button("Clear vote", role: .destructive) {
                Task { await submitVote(proposal, ranking: nil) }
            }
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

    @MainActor
    private func submitVote(_ proposal: FlightProposal, ranking: Int?) async {
        do {
            try await viewModel.submitRanking(proposalId: proposal.id, ranking: ranking)
        } catch let error as APIError {
            let message: String
            switch error {
            case .httpStatus(let statusCode, _):
                message = "Status code: \(statusCode)."
            default:
                message = error.errorDescription ?? "Something went wrong while submitting the vote."
            }
            alertInfo = AlertInfo(title: "Unable to Vote", message: message)
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Vote",
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

    func submitRanking(proposalId: Int, ranking: Int?) async throws {
        guard let flightsAPI else {
            throw APIError.invalidResponse
        }

        guard let index = proposals.firstIndex(where: { $0.id == proposalId }) else {
            return
        }

        let originalProposals = proposals
        let originalProposal = proposals[index]
        let updatedProposal = applyRankingChange(to: originalProposal, ranking: ranking)
        var updatedProposals = proposals
        updatedProposals[index] = updatedProposal
        applyProposals(updatedProposals)

        do {
            if let ranking {
                if let updatedRanking = try await flightsAPI.submitFlightProposalRanking(
                    proposalId: proposalId,
                    ranking: ranking
                ) {
                    updateProposalRanking(proposalId: proposalId, ranking: updatedRanking)
                } else {
                    await loadProposals()
                }
            } else if originalProposal.currentUserRanking != nil {
                try await flightsAPI.deleteFlightProposalRanking(proposalId: proposalId)
                await loadProposals()
            }
        } catch {
            applyProposals(originalProposals)
            throw error
        }
    }

    private func removeProposal(withId proposalId: Int) {
        let updated = proposals.filter { $0.id != proposalId }
        applyProposals(updated)
    }

    private func applyProposals(_ proposals: [FlightProposal]) {
        let filtered = proposals.filter { !$0.isCanceled }
        let sorted = sortProposals(filtered)
        self.proposals = sorted
        state = sorted.isEmpty ? .empty : .loaded(sorted)
    }

    private func sortProposals(_ proposals: [FlightProposal]) -> [FlightProposal] {
        proposals.sorted { lhs, rhs in
            let leftValue = lhs.averageRanking ?? Double.greatestFiniteMagnitude
            let rightValue = rhs.averageRanking ?? Double.greatestFiniteMagnitude
            if leftValue == rightValue {
                return lhs.id < rhs.id
            }
            return leftValue < rightValue
        }
    }

    private func applyRankingChange(to proposal: FlightProposal, ranking: Int?) -> FlightProposal {
        var updated = proposal
        var updatedRankings = proposal.rankings

        if let ranking {
            if let current = proposal.currentUserRanking {
                if let rankingId = current.id,
                   let index = updatedRankings.firstIndex(where: { $0.id == rankingId }) {
                    updatedRankings[index] = current.updating(rank: ranking)
                } else if let index = updatedRankings.firstIndex(where: { $0.id == nil && $0.rank == current.rank }) {
                    updatedRankings[index] = current.updating(rank: ranking)
                } else {
                    updatedRankings.append(current.updating(rank: ranking))
                }
                updated.currentUserRanking = current.updating(rank: ranking)
            } else {
                let newRanking = FlightProposalRanking(id: nil, rank: ranking, userId: nil, userName: nil)
                updatedRankings.append(newRanking)
                updated.currentUserRanking = newRanking
            }
        } else if let current = proposal.currentUserRanking {
            if let rankingId = current.id {
                updatedRankings.removeAll { $0.id == rankingId }
            } else if let index = updatedRankings.firstIndex(where: { $0.id == nil && $0.rank == current.rank }) {
                updatedRankings.remove(at: index)
            }
            updated.currentUserRanking = nil
        }

        updated.rankings = updatedRankings
        updated.averageRanking = averageRanking(from: updatedRankings)
        return updated
    }

    private func updateProposalRanking(proposalId: Int, ranking: FlightProposalRanking) {
        guard let index = proposals.firstIndex(where: { $0.id == proposalId }) else { return }
        var proposal = proposals[index]
        var updatedRankings = proposal.rankings.filter { $0.id != ranking.id }
        if let index = updatedRankings.firstIndex(where: { $0.id == nil && $0.rank == proposal.currentUserRanking?.rank }) {
            updatedRankings.remove(at: index)
        }
        updatedRankings.append(ranking)
        proposal.rankings = updatedRankings
        proposal.currentUserRanking = ranking
        proposal.averageRanking = averageRanking(from: updatedRankings)
        var updatedProposals = proposals
        updatedProposals[index] = proposal
        applyProposals(updatedProposals)
    }

    private func averageRanking(from rankings: [FlightProposalRanking]) -> Double? {
        guard !rankings.isEmpty else { return nil }
        let total = rankings.reduce(0) { $0 + $1.rank }
        return Double(total) / Double(rankings.count)
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
    let onVote: () -> Void
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
            } else {
                voteRow

                if proposal.canShowCancel {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var voteRow: some View {
        HStack(spacing: 12) {
            Button {
                onVote()
            } label: {
                Text(voteButtonTitle)
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Avg: \(averageText)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if proposal.averageRanking == 1 {
                Text("Top Choice")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGreen).opacity(0.2))
                    )
                    .foregroundStyle(.green)
            }
        }
    }

    private var routeText: String {
        let route = proposal.routeText
        return route.isEmpty ? "Route TBD" : route
    }

    private var voteButtonTitle: String {
        if let ranking = proposal.currentUserRanking?.rank {
            return "Your choice: #\(ranking)"
        }
        return "Vote"
    }

    private var averageText: String {
        guard let average = proposal.averageRanking else { return "—" }
        return String(format: "%.1f", average)
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
