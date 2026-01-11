import SwiftUI

struct TripsListView: View {
    let user: User

    @State private var state: TripsState = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading trips...")
            case .loaded(let trips):
                if trips.isEmpty {
                    ContentUnavailableView("No Trips Yet", systemImage: "airplane", description: Text("Create your first trip to get started."))
                } else {
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
                }
            case .error(let message):
                VStack(spacing: 12) {
                    Text("Unable to load trips")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        state = .loading
                        Task {
                            await loadTrips()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle("Trips")
        .task {
            if case .loading = state {
                await loadTrips()
            }
        }
    }

    private func loadTrips() async {
        do {
            let api = try TripsAPI()
            let trips = try await api.fetchTrips()
            state = .loaded(trips)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

private enum TripsState {
    case loading
    case loaded([TripCalendar])
    case error(String)
}

#Preview {
    NavigationStack {
        TripsListView(user: User(id: "1", email: "user@example.com", username: nil, firstName: nil, lastName: nil, phoneNumber: nil, profileImageUrl: nil, defaultLocation: nil, defaultLocationCode: nil, defaultCity: nil, defaultCountry: nil, authProvider: nil, hasSeenHomeOnboarding: false, hasSeenTripOnboarding: false, createdAt: nil, updatedAt: nil))
    }
}
