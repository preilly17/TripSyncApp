import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let phoneNumber: String?
    let profileImageUrl: String?
    let defaultLocation: String?
    let defaultLocationCode: String?
    let defaultCity: String?
    let defaultCountry: String?
    let authProvider: String?
    let hasSeenHomeOnboarding: Bool
    let hasSeenTripOnboarding: Bool
    let createdAt: String?
    let updatedAt: String?
}
