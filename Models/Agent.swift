import Foundation

struct Agent: Identifiable, Codable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var brokerName: String
    var emergencyContacts: [EmergencyContact]
}

struct EmergencyContact: Codable, Identifiable {
    var id: UUID { UUID() }
    let name: String
    let relationship: String
    let phoneNumber: String
}
