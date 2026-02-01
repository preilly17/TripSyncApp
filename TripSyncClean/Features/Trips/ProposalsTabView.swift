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
                                isVoting: viewModel.votingProposalIds.contains(proposal.id),
                                currentUser: viewModel.currentUser,
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
        .task {
            await viewModel.loadCurrentUser()
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
                message = "We couldn't cancel that proposal. Please try again."
            default:
                message = "We couldn't cancel that proposal. Please try again."
            }
            alertInfo = AlertInfo(title: "Unable to Cancel", message: message)
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Cancel",
                message: "We couldn't cancel that proposal. Please try again."
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
                message = "We couldn't save your vote. Please try again."
            default:
                message = "We couldn't save your vote. Please try again."
            }
            alertInfo = AlertInfo(title: "Unable to Vote", message: message)
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Vote",
                message: "We couldn't save your vote. Please try again."
            )
        }
    }
}

@MainActor
final class FlightProposalsViewModel: ObservableObject {
    @Published var state: FlightProposalsState = .loading
    @Published var proposals: [FlightProposal] = []
    @Published var cancelingProposalId: Int?
    @Published var votingProposalIds: Set<Int> = []
    @Published var currentUser: User?

    private let tripId: Int
    private let flightsAPI: FlightsAPI?
    private let authAPI: AuthAPI?

    init(tripId: Int, flightsAPI: FlightsAPI?) {
        self.tripId = tripId
        self.flightsAPI = flightsAPI
        self.authAPI = try? AuthAPI()
    }

    func loadCurrentUser() async {
        guard let authAPI else { return }
        do {
            currentUser = try await authAPI.currentUser()
        } catch {
            currentUser = nil
        }
    }

    func loadProposals() async {
        guard let flightsAPI else {
            state = .error("Missing API configuration.")
            return
        }

        do {
            let proposals = try await flightsAPI.fetchFlightProposals(tripId: tripId)
            applyProposals(proposals, animated: true)
        } catch let error as APIError {
            proposals = []
            state = .error(userFacingMessage(for: error, fallback: "Unable to load proposals."))
        } catch {
            proposals = []
            state = .error("Unable to load proposals.")
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
        applyProposals(updatedProposals, animated: true)
        votingProposalIds.insert(proposalId)

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
            votingProposalIds.remove(proposalId)
        } catch {
            votingProposalIds.remove(proposalId)
            applyProposals(originalProposals, animated: true)
            throw error
        }
    }

    private func removeProposal(withId proposalId: Int) {
        let updated = proposals.filter { $0.id != proposalId }
        applyProposals(updated, animated: true)
    }

    private func applyProposals(_ proposals: [FlightProposal], animated: Bool = false) {
        let filtered = proposals.filter { !$0.isCanceled }
        let sorted = sortProposals(filtered)
        let applyChanges = {
            self.proposals = sorted
            self.state = sorted.isEmpty ? .empty : .loaded(sorted)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                applyChanges()
            }
        } else {
            applyChanges()
        }
    }

    private func sortProposals(_ proposals: [FlightProposal]) -> [FlightProposal] {
        proposals.sorted { lhs, rhs in
            let leftValue = lhs.displayAverageRanking ?? Double.greatestFiniteMagnitude
            let rightValue = rhs.displayAverageRanking ?? Double.greatestFiniteMagnitude
            if leftValue == rightValue {
                return lhs.id > rhs.id
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
        applyProposals(updatedProposals, animated: true)
    }

    private func averageRanking(from rankings: [FlightProposalRanking]) -> Double? {
        guard !rankings.isEmpty else { return nil }
        let total = rankings.reduce(0) { $0 + $1.rank }
        return Double(total) / Double(rankings.count)
    }

    private func userFacingMessage(for error: APIError, fallback: String) -> String {
        switch error {
        case .missingConfiguration:
            return fallback
        case .invalidBaseURL, .invalidURL, .invalidResponse:
            return fallback
        case .unauthorized:
            return "Please sign in again to view proposals."
        case .httpStatus:
            return fallback
        case .decoding, .transport:
            return fallback
        }
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
    let isVoting: Bool
    let currentUser: User?
    let onVote: () -> Void
    let onCancel: () -> Void

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

            if let proposedBy = proposal.proposerDisplayName(currentUser: currentUser) {
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
            .disabled(isVoting)

            Spacer()

            if isVoting {
                ProgressView()
            }

            Text("Avg: \(averageText)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if proposal.displayAverageRanking.map(isTopChoice) == true {
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
        guard let average = proposal.displayAverageRanking else { return "—" }
        return String(format: "%.1f", average)
    }

    private var timeRowValue: String {
        let departText = formattedDate(proposal.departDate, fallback: proposal.departDateTimeRaw)
        let arriveText = formattedDate(proposal.arriveDate, fallback: proposal.arriveDateTimeRaw)
        return "\(departText) → \(arriveText)"
    }

    private func formattedDate(_ date: Date?, fallback: String?) -> String {
        if let formatted = FlightDateFormatter.dateTimeString(from: date) {
            return formatted
        }
        if let fallback, !fallback.isEmpty {
            return fallback
        }
        return "TBD"
    }

    private func isTopChoice(average: Double) -> Bool {
        abs(average - 1.0) < 0.05
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
