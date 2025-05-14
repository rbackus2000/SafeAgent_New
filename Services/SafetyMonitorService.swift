import Foundation
import CoreLocation
import CoreData
import Combine
import UserNotifications
import MapKit

class SafetyMonitorService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var isInDanger = false
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String? = nil
    
    override init() {
        super.init()
        setupLocationMonitoring()
    }
    
    private func setupLocationMonitoring() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func triggerPanicButton() {
        isInDanger = true
        sendLocalNotification()
        notifyEmergencyContacts()
        alertLocalAuthorities()
    }
    
    private func sendLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Panic Alarm Activated"
        content.body = "Emergency contacts and authorities have been notified."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Local notification error: \(error.localizedDescription)")
            }
        }
    }
    
    private func notifyEmergencyContacts() {
        // Implement SMS/Call notification to emergency contacts
    }
    
    private func alertLocalAuthorities() {
        // Implement emergency service notification
        // Could integrate with local 911 dispatch API
    }
    
    func checkProximityToAppointment(_ appointment: AppointmentEntity) {
        guard let currentLocation = currentLocation else { return }
        
        let appointmentLocation = CLLocationCoordinate2D(
            latitude: appointment.latitude,
            longitude: appointment.longitude
        )
        
        let distance = CLLocation(
            latitude: currentLocation.latitude, 
            longitude: currentLocation.longitude
        ).distance(from: CLLocation(
            latitude: appointmentLocation.latitude, 
            longitude: appointmentLocation.longitude
        ))
        
        if distance < 100 { // Within 100 meters
            // Activate safety monitoring for this specific appointment
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = error.localizedDescription
        print("Location monitoring error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationStatus = manager.authorizationStatus
            print("Location status changed: \(self.locationStatus.rawValue)")
        }
    }
    
    func promptForAlwaysAuthorizationIfNeeded() {
        if locationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
}
