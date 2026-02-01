import SwiftUI

struct FlightsListView: View {
    @StateObject private var viewModel: FlightsViewModel
    @State private var showingAddFlightSheet = false
    @State private var alertInfo: AlertInfo?

    init(tripId: Int, flightsAPI: FlightsAPI? = nil) {
        let resolvedAPI = flightsAPI ?? (try? FlightsAPI())
        _viewModel = StateObject(wrappedValue: FlightsViewModel(tripId: tripId, flightsAPI: resolvedAPI))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading flights")
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .empty:
                ContentUnavailableView(
                    "No flights yet",
                    systemImage: "airplane",
                    description: Text("Add your flights to keep the trip organized.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            case .loaded(let flights):
                LazyVStack(spacing: 12) {
                    ForEach(flights) { flight in
                        FlightRowCard(
                            flight: flight,
                            isProposing: viewModel.proposingFlightId == flight.id
                        ) {
                            Task {
                                await proposeFlight(flight)
                            }
                        }
                    }
                }
            case .error(let message):
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Unable to load flights")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            }
        }
        .task {
            if case .loading = viewModel.state {
                await viewModel.loadFlights()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddFlightSheet = true
                } label: {
                    Label("Add Flight", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFlightSheet) {
            AddFlightSheetView(viewModel: viewModel)
        }
        .alert(item: $alertInfo) { info in
            Alert(title: Text(info.title), message: Text(info.message))
        }
    }

    @MainActor
    private func proposeFlight(_ flight: Flight) async {
        print("✈️ Propose tapped for flight id: \(flight.id)")

        do {
            try await viewModel.proposeFlight(flightId: flight.id)
            alertInfo = AlertInfo(
                title: "Flight Proposed",
                message: "Your flight proposal was submitted."
            )
        } catch let error as APIError {
            alertInfo = AlertInfo(
                title: "Unable to Propose",
                message: error.errorDescription ?? "Something went wrong while proposing the flight."
            )
        } catch {
            alertInfo = AlertInfo(
                title: "Unable to Propose",
                message: error.localizedDescription
            )
        }
    }
}

@MainActor
final class FlightsViewModel: ObservableObject {
    @Published var state: FlightsState = .loading
    @Published var proposingFlightId: Int?

    private let tripId: Int
    private let flightsAPI: FlightsAPI?

    init(tripId: Int, flightsAPI: FlightsAPI?) {
        self.tripId = tripId
        self.flightsAPI = flightsAPI
    }

    func loadFlights() async {
        guard let flightsAPI else {
            state = .error("Missing API configuration.")
            return
        }

        do {
            let flights = try await flightsAPI.fetchFlights(tripId: tripId)
            state = flights.isEmpty ? .empty : .loaded(flights)
        } catch let error as APIError {
            state = .error(error.errorDescription ?? "Unable to load flights.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func refresh() async {
        await loadFlights()
    }

    func addManualFlight(payload: AddFlightPayload) async throws {
        guard let flightsAPI else {
            throw APIError.invalidResponse
        }

        try await flightsAPI.addManualFlight(tripId: tripId, payload: payload)
    }

    func proposeFlight(flightId: Int) async throws {
        guard let flightsAPI else {
            throw APIError.invalidResponse
        }

        proposingFlightId = flightId
        defer { proposingFlightId = nil }
        try await flightsAPI.proposeFlight(tripId: tripId, flightId: flightId)
    }

    func cancelFlightProposal(proposalId: Int) async throws {
        guard let flightsAPI else {
            throw APIError.invalidResponse
        }

        try await flightsAPI.cancelFlightProposal(proposalId: proposalId)
    }
}

enum FlightsState {
    case loading
    case empty
    case loaded([Flight])
    case error(String)
}

private struct FlightRowCard: View {
    let flight: Flight
    let isProposing: Bool
    let onPropose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.displayTitle)
                        .font(.headline)

                    Text(flight.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let status = flight.status, !status.isEmpty {
                    Text(status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Departs")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(formattedDateTime(flight.departureDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Arrives")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(formattedDateTime(flight.arrivalDate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            if let durationStopsText {
                Text(durationStopsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let pricePointsText {
                Text(pricePointsText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let source = sourceText {
                Text("Source: \(source)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    onPropose()
                } label: {
                    if isProposing {
                        ProgressView()
                    } else {
                        Text("Propose")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isProposing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func formattedDateTime(_ date: Date?) -> String {
        if let formatted = FlightDateFormatter.dateTimeString(from: date) {
            return formatted
        }
        return "TBD"
    }

    private var sourceText: String? {
        if let bookingUrl = flight.bookingUrl,
           !bookingUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return bookingUrl
        }
        if let platform = flight.platform,
           !platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return platform
        }
        return nil
    }

    private var durationStopsText: String? {
        var parts: [String] = []
        if let duration = flight.duration, !duration.isEmpty {
            parts.append(duration)
        }
        if let stops = flight.stops {
            let label: String
            if stops == 0 {
                label = "Nonstop"
            } else if stops == 1 {
                label = "1 stop"
            } else {
                label = "\(stops) stops"
            }
            parts.append(label)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var pricePointsText: String? {
        if let pointsCost = flight.pointsCost {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let formatted = formatter.string(from: NSNumber(value: pointsCost)) ?? "\(pointsCost)"
            return "Points: \(formatted)"
        }

        if let price = flight.price, !price.isEmpty {
            if let currency = flight.currency, !currency.isEmpty {
                return "\(price) \(currency)"
            }
            return price
        }

        return nil
    }
}

private struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    FlightsListView(tripId: 1, flightsAPI: nil)
        .padding()
}
