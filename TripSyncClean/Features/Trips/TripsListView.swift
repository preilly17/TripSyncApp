import SwiftUI

struct TripsListView: View {
    @StateObject private var viewModel: TripsListViewModel

    init(tripsAPI: TripsAPI?) {
        _viewModel = StateObject(wrappedValue: TripsListViewModel(tripsAPI: tripsAPI))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView("Loading trips")
            case .loaded(let trips):
                List(trips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name)
                                .font(.headline)
                            Text(trip.destination)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(trip.startDate) - \(trip.endDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .empty:
                ContentUnavailableView("No trips yet", systemImage: "airplane")
            }
        }
        .navigationTitle("My Trips")
        .task {
            if case .loading = viewModel.state {
                await viewModel.loadTrips()
            }
        }
    }
}

@MainActor
final class TripsListViewModel: ObservableObject {
    @Published var state: TripsState = .loading
    private let tripsAPI: TripsAPI?

    init(tripsAPI: TripsAPI?) {
        self.tripsAPI = tripsAPI
    }

    func loadTrips() async {
        guard let tripsAPI else {
            state = .empty
            return
        }

        do {
            let trips = try await tripsAPI.fetchTrips()
            state = trips.isEmpty ? .empty : .loaded(trips)
        } catch {
            state = .empty
        }
    }
}

enum TripsState {
    case loading
    case loaded([TripCalendar])
    case empty
}

#Preview {
    NavigationStack {
        TripsListView(tripsAPI: nil)
    }
}
