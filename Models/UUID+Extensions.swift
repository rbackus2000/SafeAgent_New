import Foundation

// Define a helper extension to fix comparison errors with UUID and ObjectIdentifier
extension UUID: Equatable {
    public static func == (lhs: UUID, rhs: UUID) -> Bool {
        return lhs.uuidString == rhs.uuidString
    }
}

// Helper to compare UUIDs safely
func sameUUID(_ id1: UUID?, _ id2: UUID?) -> Bool {
    if let id1 = id1, let id2 = id2 {
        return id1.uuidString == id2.uuidString
    }
    return false
} 