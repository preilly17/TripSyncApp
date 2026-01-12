import Foundation

struct TripCalendar: Identifiable, Codable {
    let id: Int
    let name: String
    let destination: String
    let startDate: String
    let endDate: String
    let travelerCount: Int?
    let planningPercentage: Int?
    let shareCode: String
    let createdBy: String
    let coverPhotoUrl: String?
}
