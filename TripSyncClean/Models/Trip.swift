import Foundation

struct Trip: Identifiable, Codable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var destinations: [Destination]
}
