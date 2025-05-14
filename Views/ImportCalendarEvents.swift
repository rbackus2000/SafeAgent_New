import EventKit
import CoreData
import CoreLocation

// Geocoding group for async geocoding
let geocodingGroup = DispatchGroup()

/// Geocodes an appointment's address and updates its coordinates
func geocodeAppointmentAddress(_ appointment: AppointmentEntity, group: DispatchGroup) {
    guard let address = appointment.propertyAddress, !address.isEmpty else { return }
    group.enter()
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString(address) { placemarks, error in
        defer { group.leave() }
        if let coordinate = placemarks?.first?.location?.coordinate {
            appointment.latitude = coordinate.latitude
            appointment.longitude = coordinate.longitude
        }
    }
}

/// Syncs EKEvents to CoreData appointments: creates new, updates changed, deletes removed.
/// Returns (imported, updated, deleted) counts.
func syncCalendarEventsToCoreData(events: [EKEvent], context: NSManagedObjectContext) -> (imported: Int, updated: Int, deleted: Int) {
    // 1. Build a lookup of eventIdentifiers from fetched events
    let eventIDs = Set(events.map { $0.eventIdentifier })
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
            // Ensure every updated appointment has an id
            if appt.id == nil || appt.id?.isEmpty == true {
                appt.id = UUID().uuidString
            }
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
    
    // MIGRATION: Assign UUIDs to any appointments missing an id
    let migrationRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
    if let allAppointments = try? context.fetch(migrationRequest) {
        var didMigrate = false
        for appt in allAppointments where appt.id == nil || appt.id?.isEmpty == true {
            appt.id = UUID().uuidString
            didMigrate = true
        }
        if didMigrate {
            try? context.save()
        }
    }

    do {
        try context.save()
    } catch {
        print("Failed to sync appointments: \(error)")
    }
    return (imported, updated, deleted)
}
