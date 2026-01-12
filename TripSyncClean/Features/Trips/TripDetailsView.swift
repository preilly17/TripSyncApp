import SwiftUI

struct TripDetailsView: View {
    let trip: TripSummaryDisplay
    @State private var selectedTab: TripDetailsTab = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                tabBar
                contentView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(TripDateFormatter.dateRangeText(start: trip.startDate, end: trip.endDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let location = trip.location {
                Text(location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TripDetailsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selectedTab == tab ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(.systemGray4), lineWidth: selectedTab == tab ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .overview:
            TripDetailsCard(title: "Trip Dashboard") {
                TripDetailsRow(label: "Dates", value: TripDateFormatter.dateRangeText(start: trip.startDate, end: trip.endDate))
                TripDetailsRow(label: "Destination", value: trip.location ?? "—")
                TripDetailsRow(label: "Members", value: "Coming soon")
            }
        case .flights:
            VStack(alignment: .leading, spacing: 12) {
                Text("Flights")
                    .font(.title3)
                    .fontWeight(.semibold)

                FlightsListView(tripId: trip.id)
            }
        case .lodging:
            TripDetailsCard(title: "Lodging — Coming soon") {
                Text("Stay information will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .activities:
            TripDetailsCard(title: "Activities — Coming soon") {
                Text("Activity planning will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .restaurants:
            TripDetailsCard(title: "Restaurants — Coming soon") {
                Text("Dining plans will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct TripSummaryDisplay: Identifiable {
    let id: Int
    let name: String
    let startDate: String
    let endDate: String
    let location: String?

    init(trip: TripCalendar) {
        id = trip.id
        name = trip.name
        startDate = trip.startDate
        endDate = trip.endDate
        location = TripSummaryDisplay.cleanLocation(from: trip.destination)
    }

    private static func cleanLocation(from destination: String) -> String? {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum TripDetailsTab: String, CaseIterable, Identifiable {
    case overview
    case flights
    case lodging
    case activities
    case restaurants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .flights:
            return "Flights"
        case .lodging:
            return "Lodging"
        case .activities:
            return "Activities"
        case .restaurants:
            return "Restaurants"
        }
    }
}

private struct TripDetailsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

private struct TripDetailsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailsView(
            trip: TripSummaryDisplay(
                trip: TripCalendar(
                    id: 1,
                    name: "Paris Getaway",
                    destination: "Paris, France",
                    startDate: "2025-03-01",
                    endDate: "2025-03-10",
                    travelerCount: 3,
                    planningPercentage: 75,
                    shareCode: "ABC123",
                    createdBy: "user1",
                    coverPhotoUrl: nil
                )
            )
        )
    }
}
