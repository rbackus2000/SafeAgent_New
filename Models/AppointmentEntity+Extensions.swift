import Foundation
import CoreData

extension AppointmentEntity {
    // MARK: - Additional Properties
    
    // Client Information
    @NSManaged public var clientName: String?
    @NSManaged public var clientPhone: String?
    @NSManaged public var clientEmail: String?
    @NSManaged public var prequalified: Bool
    @NSManaged public var notes: String?
    
    // Property Information
    @NSManaged public var listingPrice: Double
    @NSManaged public var squareFeet: Int32
    @NSManaged public var bedrooms: Int16
    @NSManaged public var bathrooms: Float
    @NSManaged public var propertyType: String?
    @NSManaged public var yearBuilt: Int16
    @NSManaged public var mlsNumber: String?
    
    // Agent Information
    @NSManaged public var listingAgent: String?
    @NSManaged public var listingAgentPhone: String?
    @NSManaged public var lockboxCode: String?
    
    // Feedback
    @NSManaged public var feedback: String?
    @NSManaged public var clientInterestLevel: Int16 // 1-5 scale
    
    // MARK: - Helper Methods
    
    var formattedListingPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        
        return formatter.string(from: NSNumber(value: listingPrice)) ?? "$0"
    }
    
    var formattedSquareFeet: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        return "\(formatter.string(from: NSNumber(value: squareFeet)) ?? "0") sq ft"
    }
    
    var propertyDetails: String {
        return "\(bedrooms) bed, \(String(format: "%.1f", bathrooms)) bath • \(formattedSquareFeet)"
    }
    
    var isUpcoming: Bool {
        guard let startTime = self.startTime else { return false }
        return startTime > Date()
    }
    
    var isCurrent: Bool {
        guard let startTime = self.startTime, let endTime = self.endTime else { return false }
        let now = Date()
        return startTime <= now && endTime >= now
    }
    
    var isPast: Bool {
        guard let endTime = self.endTime else { return false }
        return endTime < Date()
    }
    
    var statusText: String {
        if isCurrent {
            return "In Progress"
        } else if isUpcoming {
            return "Upcoming"
        } else {
            return "Completed"
        }
    }
    
    var timeRemainingText: String? {
        guard let startTime = self.startTime else { return nil }
        
        let now = Date()
        
        if startTime > now {
            // Upcoming appointment
            let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: startTime)
            
            if let days = components.day, days > 0 {
                return "in \(days) day\(days > 1 ? "s" : "")"
            } else if let hours = components.hour, hours > 0 {
                return "in \(hours) hour\(hours > 1 ? "s" : "")"
            } else if let minutes = components.minute {
                return "in \(minutes) minute\(minutes > 1 ? "s" : "")"
            }
        } else if let endTime = self.endTime, endTime > now {
            // Current appointment
            let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: endTime)
            
            if let hours = components.hour, hours > 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "") left"
            } else if let minutes = components.minute {
                return "\(minutes) minute\(minutes > 1 ? "s" : "") left"
            }
        }
        
        return nil
    }
} 