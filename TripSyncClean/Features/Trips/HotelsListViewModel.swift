import Foundation

@MainActor
final class HotelsListViewModel: ObservableObject {
    @Published var state: HotelsState = .loading

    private let tripId: Int
    private let hotelsAPI: HotelsAPI?

    init(tripId: Int, hotelsAPI: HotelsAPI?) {
        self.tripId = tripId
        self.hotelsAPI = hotelsAPI
    }

    func load() async {
        guard let hotelsAPI else {
            state = .error("Missing API configuration.")
            return
        }

        state = .loading
        do {
            let hotels = try await hotelsAPI.fetchHotels(tripId: tripId)
            state = hotels.isEmpty ? .empty : .loaded(hotels)
        } catch let error as APIError {
            state = .error(error.errorDescription ?? "Unable to load hotels.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func addHotel(payload: AddHotelPayload) async throws {
        guard let hotelsAPI else {
            throw APIError.invalidResponse
        }

        _ = try await hotelsAPI.addHotel(tripId: tripId, payload: payload)
        await load()
    }
}

enum HotelsState {
    case loading
    case loaded([Hotel])
    case empty
    case error(String)
}
