import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentCloudKitContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SafeAgent")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            for entity in container.managedObjectModel.entities {
                print("Loaded entity: \(entity.name ?? "nil")")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // Debug method to check for appointments with missing coordinates
    func checkAppointmentCoordinates() {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<AppointmentEntity> = AppointmentEntity.fetchRequest()
        
        do {
            let appointments = try context.fetch(fetchRequest)
            print("📊 Total appointments: \(appointments.count)")
            
            var missingCoordinates = 0
            var zeroCoordinates = 0
            var validCoordinates = 0
            
            for (index, appointment) in appointments.enumerated() {
                if appointment.latitude == 0 && appointment.longitude == 0 {
                    zeroCoordinates += 1
                    print("⚠️ Appointment #\(index+1): '\(appointment.title ?? "No Title")' has zero coordinates")
                    
                    // Print additional diagnostic info
                    if let address = appointment.propertyAddress, !address.isEmpty {
                        print("   📍 Address: \(address)")
                    } else {
                        print("   ❌ Missing address")
                    }
                } else if appointment.latitude != 0 || appointment.longitude != 0 {
                    validCoordinates += 1
                    print("✅ Appointment #\(index+1): '\(appointment.title ?? "No Title")' has valid coordinates: \(appointment.latitude), \(appointment.longitude)")
                } else {
                    missingCoordinates += 1
                    print("❓ Appointment #\(index+1): '\(appointment.title ?? "No Title")' has unknown coordinate status")
                }
            }
            
            print("📊 Coordinates Summary:")
            print("   ✅ Valid coordinates: \(validCoordinates)")
            print("   ⚠️ Zero coordinates: \(zeroCoordinates)")
            print("   ❓ Unknown status: \(missingCoordinates)")
        } catch {
            print("❌ Error fetching appointments: \(error.localizedDescription)")
        }
    }
}
