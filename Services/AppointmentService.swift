import Foundation
import CoreData
import CoreLocation
import SwiftUI

class AppointmentService {
    static let shared = AppointmentService()
    
    private init() {}
    
    // Function to update appointment coordinates
    func updateAppointmentCoordinates(appointmentId: UUID, latitude: Double, longitude: Double) {
        // Get the context
        let context = PersistenceController.shared.container.viewContext
        
        // Create a fetch request to find the specific appointment
        let fetchRequest: NSFetchRequest<AppointmentEntity> = AppointmentEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", appointmentId.uuidString)
        
        do {
            // Attempt to fetch the appointment
            let appointments = try context.fetch(fetchRequest)
            
            if let appointmentToUpdate = appointments.first {
                print("🔄 Updating coordinates for appointment: \(appointmentToUpdate.id ?? "unknown")")
                
                // Update the coordinates
                appointmentToUpdate.latitude = latitude
                appointmentToUpdate.longitude = longitude
                
                // Save the context
                try context.save()
                
                print("✅ Coordinates updated successfully")
                
                // Post a notification to refresh views
                NotificationCenter.default.post(
                    name: Notification.Name("AppointmentCoordinatesUpdated"),
                    object: nil,
                    userInfo: ["appointmentId": appointmentId]
                )
            } else {
                print("❌ No appointment found with ID: \(appointmentId)")
            }
        } catch {
            print("❌ Error updating coordinates: \(error.localizedDescription)")
        }
    }
    
    // Function to update appointment status
    func updateAppointmentStatus(appointmentId: UUID, status: String) {
        // Get the context
        let context = PersistenceController.shared.container.viewContext
        
        // Create a fetch request to find the specific appointment
        let fetchRequest: NSFetchRequest<AppointmentEntity> = AppointmentEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", appointmentId.uuidString)
        
        do {
            // Attempt to fetch the appointment
            let appointments = try context.fetch(fetchRequest)
            
            if let appointmentToUpdate = appointments.first {
                print("🔄 Updating status for appointment: \(appointmentToUpdate.id ?? "unknown") to \(status)")
                
                // Update the status
                appointmentToUpdate.status = status
                
                // Save the context
                try context.save()
                
                print("✅ Status updated successfully")
                
                // Post a notification to refresh views
                NotificationCenter.default.post(
                    name: Notification.Name("AppointmentStatusChanged"),
                    object: nil,
                    userInfo: [
                        "appointmentId": appointmentId,
                        "status": status
                    ]
                )
            } else {
                print("❌ No appointment found with ID: \(appointmentId)")
            }
        } catch {
            print("❌ Error updating status: \(error.localizedDescription)")
        }
    }
    
    // Additional appointment-related utility functions can be added here
} 