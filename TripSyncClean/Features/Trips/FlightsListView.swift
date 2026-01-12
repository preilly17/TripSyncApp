import SwiftUI

struct FlightsListView: View {
    @StateObject private var viewModel: FlightsViewModel

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
                        FlightRowCard(flight: flight)
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
    }
}

@MainActor
final class FlightsViewModel: ObservableObject {
    @Published var state: FlightsState = .loading

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
}

enum FlightsState {
    case loading
    case empty
    case loaded([Flight])
    case error(String)
}

private struct FlightRowCard: View {
    let flight: Flight

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

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

            VStack(alignment: .leading, spacing: 4) {
                Text(timeRowTitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(timeRowValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if let bookingSource = flight.bookingSource, !bookingSource.isEmpty {
                Text("Source: \(bookingSource)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var timeRowTitle: String {
        let route = flight.routeText
        return route.isEmpty ? "Depart → Arrive" : route
    }

    private var timeRowValue: String {
        let departText = formattedDate(flight.departDate, fallback: flight.departDateTimeRaw)
        let arriveText = formattedDate(flight.arriveDate, fallback: flight.arriveDateTimeRaw)
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

#Preview {
    FlightsListView(tripId: 1, flightsAPI: nil)
        .padding()
}
