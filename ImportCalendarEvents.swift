import EventKit
import CoreData
import CoreLocation

/// Syncs EKEvents to Core Data appointments: creates new, updates changed, deletes removed.
/// Returns (imported, updated, deleted) counts.
func syncCalendarEventsToCoreData(events: [EKEvent], context: NSManagedObjectContext) -> (imported: Int, updated: Int, deleted: Int) {
    // 1. Build a lookup of eventIdentifiers from fetched events
    let eventIDs = Set(events.compactMap { $0.eventIdentifier })
    var imported = 0
    var updated = 0
    var deleted = 0

    // 2. Fetch all existing CoreData appointments with eventIdentifier
    let request = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
    request.predicate = NSPredicate(format: "eventIdentifier != nil")
    let existingAppointments = (try? context.fetch(request)) ?? []

    // 3. Map for quick lookup
    var appointmentByEventID = [String: AppointmentEntity]()
    for appt in existingAppointments {
        if let eid = appt.eventIdentifier {
            appointmentByEventID[eid] = appt
        }
    }

    // Create a dispatch group to wait for all geocoding operations
    let geocodingGroup = DispatchGroup()
    
    // 4. Update or insert appointments
    for event in events {
        // Safely unwrap all required fields
        guard let eventID = event.eventIdentifier,
              let title = event.title,
              let startDate = event.startDate,
              let endDate = event.endDate else {
            // Skip events missing required fields
            continue
        }
        let propertyAddress = event.location // propertyAddress is optional in Core Data

        if let appt = appointmentByEventID[eventID] {
            var changed = false
            if appt.title != title { appt.title = title; changed = true }
            if appt.propertyAddress != propertyAddress { appt.propertyAddress = propertyAddress; changed = true }
            if appt.startTime != startDate { appt.startTime = startDate; changed = true }
            if appt.endTime != endDate { appt.endTime = endDate; changed = true }
            
            // If the address changed or there are no coordinates, try to geocode
            if (changed && appt.propertyAddress != nil) || (appt.latitude == 0 && appt.longitude == 0 && appt.propertyAddress != nil) {
                geocodeAppointmentAddress(appt, group: geocodingGroup)
            }
            
            if changed { updated += 1 }
            appointmentByEventID.removeValue(forKey: eventID)
        } else {
            let appt = AppointmentEntity(context: context)
            appt.id = UUID().uuidString
            appt.title = title
            appt.propertyAddress = propertyAddress
            appt.startTime = startDate
            appt.endTime = endDate
            appt.status = "scheduled"
            appt.eventIdentifier = eventID
            
            // Try to geocode the address for new appointments
            if let address = propertyAddress {
                geocodeAppointmentAddress(appt, group: geocodingGroup)
            }
            
            imported += 1
        }
    }

    // 5. Delete appointments whose eventIdentifier is no longer present
    for (_, appt) in appointmentByEventID {
        context.delete(appt)
        deleted += 1
    }
    
    // 6. Save all changes
    do {
        // Save context and wait for geocoding to complete
        geocodingGroup.notify(queue: .main) {
            do {
                try context.save()
                print("✅ Successfully saved \(imported) imported, \(updated) updated, \(deleted) deleted appointments")
            } catch {
                print("❌ Failed to save appointments: \(error.localizedDescription)")
            }
        }
        
        // Save here too in case geocoding takes a long time
        if context.hasChanges {
            try context.save()
        }
    } catch {
        print("❌ Failed to sync appointments: \(error.localizedDescription)")
    }
    
    return (imported, updated, deleted)
}

/// Cleans up an address from calendar invites to make it more geocoder-friendly
func cleanupAddressFromCalendar(_ originalAddress: String) -> String {
    var address = originalAddress
    
    print("🔍 ORIGINAL ADDRESS: '\(originalAddress)'")
    
    // Remove common prefixes that might be in calendar invites
    let prefixesToRemove = [
        "Showing @", "Showing at", "Showing -", "Showing:", "Showing", 
        "Property @", "Property at", "Property -", "Property:", "Property",
        "Open House @", "Open House at", "Open House -", "Open House:", "Open House"
    ]
    
    for prefix in prefixesToRemove {
        if address.lowercased().hasPrefix(prefix.lowercased()) {
            address = String(address.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            print("✂️ Removed prefix: '\(prefix)' -> '\(address)'")
            break
        }
    }
    
    // Check if the address contains a city, state, zip
    if !address.contains(",") {
        print("⚠️ Address missing commas: '\(address)'")
    }
    
    print("🏠 CLEANED ADDRESS: '\(address)'")
    return address
}

/// Geocodes an appointment's address and updates its coordinates
private func geocodeAppointmentAddress(_ appointment: AppointmentEntity, group: DispatchGroup) {
    guard let address = appointment.propertyAddress, !address.isEmpty else { 
        print("❌ Empty address for appointment: \(appointment.title ?? "Unknown")")
        return 
    }
    
    group.enter()
    
    // Clean up the address before geocoding
    let cleanAddress = cleanupAddressFromCalendar(address)
    print("🌎 Geocoding calendar address: '\(cleanAddress)' (original: '\(address)')")
    
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString(cleanAddress) { placemarks, error in
        defer { group.leave() }
        
        if let error = error {
            print("❌ Calendar geocoding error: \(error.localizedDescription)")
            
            // Try again with just the numeric part of the address if it failed
            if let numericAddress = extractNumericAddress(from: cleanAddress) {
                print("🔄 Retrying with numeric address: '\(numericAddress)'")
                retryGeocoding(numericAddress, for: appointment)
            }
            return
        }
        
        if let coordinate = placemarks?.first?.location?.coordinate {
            print("✅ Successfully geocoded '\(cleanAddress)' to: \(coordinate.latitude), \(coordinate.longitude)")
            appointment.latitude = coordinate.latitude
            appointment.longitude = coordinate.longitude
        } else {
            print("❌ No coordinates found for: '\(cleanAddress)'")
            
            // Try again with just the numeric part of the address
            if let numericAddress = extractNumericAddress(from: cleanAddress) {
                print("🔄 Retrying with numeric address: '\(numericAddress)'")
                retryGeocoding(numericAddress, for: appointment)
            }
        }
    }
}

/// Extracts just the numeric part of an address (e.g., "123 Main St")
private func extractNumericAddress(from address: String) -> String? {
    // Match patterns like "123 Main St" from addresses
    let pattern = "\\d+\\s+[A-Za-z\\s]+"
    
    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
       let match = regex.firstMatch(in: address, options: [], range: NSRange(location: 0, length: address.utf16.count)) {
        if let range = Range(match.range, in: address) {
            let numericAddress = String(address[range])
            return numericAddress
        }
    }
    return nil
}

/// Retry geocoding with a simplified address
private func retryGeocoding(_ address: String, for appointment: AppointmentEntity) {
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString(address) { placemarks, error in
        if let error = error {
            print("❌ Retry geocoding error: \(error.localizedDescription)")
            return
        }
        
        if let coordinate = placemarks?.first?.location?.coordinate {
            print("✅ Retry succeeded! Geocoded '\(address)' to: \(coordinate.latitude), \(coordinate.longitude)")
            appointment.latitude = coordinate.latitude
            appointment.longitude = coordinate.longitude
            
            // Save the context
            do {
                try PersistenceController.shared.container.viewContext.save()
                print("💾 Saved coordinates after retry")
            } catch {
                print("❌ Error saving context after retry: \(error)")
            }
        } else {
            print("❌ Retry failed: No coordinates found for '\(address)'")
        }
    }
} 