import SwiftUI

struct TripDetailView: View {
    let trip: TripCalendar

    var body: some View {
        VStack(spacing: 12) {
            Text(trip.name)
                .font(.title)
            Text("Trip ID: \(trip.id)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: TripCalendar(id: 1, name: "Paris Getaway", destination: "Paris", startDate: "2025-03-01", endDate: "2025-03-10", shareCode: "ABC123", createdBy: "user1", coverPhotoUrl: nil))
    }
}
