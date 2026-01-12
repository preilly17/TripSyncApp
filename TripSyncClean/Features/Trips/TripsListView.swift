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
                TripsDateFormatter.startDate(for: lhs) < TripsDateFormatter.startDate(for: rhs)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.name)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(TripsDateFormatter.dateRangeText(start: trip.startDate, end: trip.endDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(TripsDateFormatter.daysToGoText(start: trip.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    Text("Open trip →")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
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

private enum TripsDateFormatter {
    static let parseFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static let parseDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let dayYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "d, yyyy"
        return formatter
    }()

    static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    static func startDate(for trip: TripCalendar) -> Date {
        parseDate(trip.startDate) ?? .distantFuture
    }

    static func dateRangeText(start: String, end: String) -> String {
        guard let startDate = parseDate(start), let endDate = parseDate(end) else {
            return "\(start)–\(end)"
        }

        let calendar = Calendar(identifier: .gregorian)
        if calendar.component(.year, from: startDate) == calendar.component(.year, from: endDate) {
            let startText = monthDayFormatter.string(from: startDate)
            let endText = dayYearFormatter.string(from: endDate)
            return "\(startText)–\(endText)"
        }

        let startText = fullDateFormatter.string(from: startDate)
        let endText = fullDateFormatter.string(from: endDate)
        return "\(startText)–\(endText)"
    }

    static func daysToGoText(start: String) -> String {
        guard let startDate = parseDate(start) else {
            return "Dates to be announced"
        }

        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: startDate)
        let dayCount = max(calendar.dateComponents([.day], from: now, to: startDay).day ?? 0, 0)
        return dayCount == 1 ? "1 day to go" : "\(dayCount) days to go"
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = parseFormatter.date(from: value) {
            return date
        }
        return parseDateTimeFormatter.date(from: value)
    }
}

#Preview {
    NavigationStack {
        TripsListView(tripsAPI: nil)
    }
}
