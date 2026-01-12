import SwiftUI

struct TripDetailView: View {
    let trip: TripCalendar
    @State private var selectedTab: TripDetailTab = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                Picker("Trip sections", selection: $selectedTab) {
                    ForEach(TripDetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                TripDetailPlaceholderView(title: selectedTab.title)
            }
            .padding()
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

            if let destinationText = destinationText {
                Text(destinationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var destinationText: String? {
        let trimmed = trip.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum TripDetailTab: String, CaseIterable, Identifiable {
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

private struct TripDetailPlaceholderView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Coming in Slice 5")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: TripCalendar(id: 1, name: "Paris Getaway", destination: "Paris", startDate: "2025-03-01", endDate: "2025-03-10", travelerCount: 3, planningPercentage: 75, shareCode: "ABC123", createdBy: "user1", coverPhotoUrl: nil))
    }
}
