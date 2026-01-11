import Foundation

struct Destination: Identifiable, Codable {
    let id: UUID
    var name: String
    var notes: String?
}
