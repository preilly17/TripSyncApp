import Foundation

struct TripsAPI {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    init() throws {
        self.client = try APIClient()
    }

    func fetchTrips() async throws -> [TripCalendar] {
        try await client.request("/api/trips")
    }
}
