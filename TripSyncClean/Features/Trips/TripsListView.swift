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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let trips):
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(trips) { trip in
                            TripCardView(trip: trip)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            case .empty:
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "airplane",
                    description: Text("Create your first trip to get started")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let sortedTrips = trips.sorted { lhs, rhs in
                TripDateFormatter.startDate(for: lhs) < TripDateFormatter.startDate(for: rhs)
            }
            state = sortedTrips.isEmpty ? .empty : .loaded(sortedTrips)
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

private struct TripCardView: View {
    let trip: TripCalendar

    var body: some View {
        NavigationLink {
            TripDetailsView(trip: TripSummaryDisplay(trip: trip))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.name)
                            .font(.headline)
                            .fontWeight(.bold)

                        Text(TripDateFormatter.dateRangeText(start: trip.startDate, end: trip.endDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(TripDateFormatter.daysToGoText(start: trip.startDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Open trip →")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }

                HStack(spacing: 16) {
                    Text(TripCardView.travelerCountText(for: trip))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(TripCardView.planningText(for: trip))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private static func travelerCountText(for trip: TripCalendar) -> String {
        let count = trip.travelerCount ?? 0
        return count == 1 ? "1 traveler" : "\(count) travelers"
    }

    private static func planningText(for trip: TripCalendar) -> String {
        let percentage = trip.planningPercentage ?? 0
        return "Planning \(percentage)%"
    }
}

#Preview {
    NavigationStack {
        TripsListView(tripsAPI: nil)
    }
}
