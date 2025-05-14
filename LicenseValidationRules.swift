import Foundation

struct StateLicenseRule {
    let minLength: Int
    let maxLength: Int
    let pattern: String // Regex pattern
    let description: String
}

struct LicenseValidationRules {
    // Add more states as you roll out
    static let rules: [String: StateLicenseRule] = [
        "TX": StateLicenseRule(
            minLength: 6,
            maxLength: 8,
            pattern: "^[0-9]{6,8}$",
            description: "Texas real estate license numbers are 6 to 8 digits."
        ),
        "CA": StateLicenseRule(
            minLength: 8,
            maxLength: 8,
            pattern: "^[0-9]{8}$",
            description: "California license numbers are exactly 8 digits."
        ),
        "NY": StateLicenseRule(
            minLength: 7,
            maxLength: 7,
            pattern: "^[A-Z0-9]{7}$",
            description: "New York license numbers are 7 alphanumeric characters."
        )
        // Add more states here
    ]
    
    static func rule(for state: String) -> StateLicenseRule? {
        rules[state]
    }
}
