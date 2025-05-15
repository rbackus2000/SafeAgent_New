import SwiftUI
import CoreLocation

// GeofenceManager to handle geofencing functionality
class GeofenceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var monitoredRegions: [String: CLCircularRegion] = [:]
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        // Listen for refresh notifications
        NotificationCenter.default.addObserver(self, 
                                              selector: #selector(handleRefreshGeofencing(_:)), 
                                              name: Notification.Name("RefreshGeofencing"), 
                                              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleRefreshGeofencing(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let showings = userInfo["showings"] as? [AppointmentEntity] {
            startMonitoring(showings: showings)
        }
    }
    
    func startMonitoring(showings: [AppointmentEntity]) {
        // Stop monitoring existing regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        monitoredRegions.removeAll()
        
        // Start monitoring new regions
        for showing in showings {
            guard showing.latitude != 0, showing.longitude != 0,
                  let title = showing.title ?? showing.propertyAddress else {
                continue
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: showing.latitude, longitude: showing.longitude)
            let identifier = "region-\(showing.objectID.uriRepresentation().lastPathComponent)"
            let region = CLCircularRegion(center: coordinate, radius: 150, identifier: identifier)
            
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            locationManager.startMonitoring(for: region)
            monitoredRegions[identifier] = region
            print("🔔 Started monitoring region: \(title) with ID: \(identifier)")
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("🚶‍♂️ Entered region: \(region.identifier)")
        // Handle region entry - can post notifications or update UI
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("🚶‍♂️ Exited region: \(region.identifier)")
        // Handle region exit - can post notifications or update UI
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ Monitoring failed for region: \(region?.identifier ?? "unknown") with error: \(error.localizedDescription)")
    }
}

struct MainTabView: View {
    @StateObject var geofenceManager = GeofenceManager()
    @StateObject var authService = AuthenticationService()
    
    var body: some View {
        TabView {
            AppointmentsView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            
            Text("Safety Features")
                .tabItem {
                    Label("Safety", systemImage: "shield.checkmark.fill")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
            
            // Add Profile tab with navigation and authService
            NavigationStack {
                ProfileView()
                    .environmentObject(authService)
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
        .environmentObject(geofenceManager)
    }
}

#Preview {
    MainTabView()
} 