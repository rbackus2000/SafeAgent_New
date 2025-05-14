import SwiftUI
import CoreLocation
import CoreData

struct PanicButtonView: View {
    @StateObject var notificationService = NotificationService()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("agentLicenseNumber") private var licenseNumber: String = ""
    @AppStorage("agentState") private var agentState: String = ""
    @State private var isSending = false
    @State private var alertShown = false
    @State private var alertSuccess = false
    @State private var alertMessage = ""
    @State private var lastMapUrl: String? = nil
    @State private var lastStaticMapUrl: String? = nil

    var body: some View {
        GeometryReader { geometry in
            let buttonDiameter = min(max(geometry.size.width * 0.45, 140), 240)
            ZStack(alignment: .top) {
                VStack {
                    Spacer()
                    Button(action: triggerPanic) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: buttonDiameter, height: buttonDiameter)
                                .shadow(radius: 10)
                            Text("PANIC")
                                .font(.system(size: buttonDiameter * 0.22, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isSending)
                    if isSending {
                        ProgressView("Sending alert...")
                    }
                    Spacer()
                }
                if alertShown, let staticMap = lastStaticMapUrl, let mapUrl = lastMapUrl {
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: staticMap)) { image in
                            image.resizable().aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 6)
                        .padding(.bottom, 8)
                        // Link("View in Google Maps", destination: URL(string: mapUrl)!)
                        //     .font(.footnote)
                        //     .foregroundColor(.blue)
                        // Spacer().frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .transition(.move(edge: .top))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .alert(isPresented: $alertShown) {
                Alert(title: Text(alertSuccess ? "Alert Sent" : "Failed"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private func triggerPanic() {
        guard let loc = locationManager.lastLocation else {
            alertMessage = "Unable to get location. Please enable location services."
            alertSuccess = false
            alertShown = true
            return
        }
        let agentId = licenseNumber.isEmpty ? UUID().uuidString : licenseNumber
        let now = Date()
        let appointment = fetchCurrentAppointment(at: now)
        let gpsString = "Lat: \(loc.coordinate.latitude), Lon: \(loc.coordinate.longitude)"
        let googleMapsApiKey = "AIzaSyBJH59c5qbcwxnSaIniAWEFTlvwfDkHwUs"
        let mapUrl = "https://maps.google.com/?q=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
        let staticMapUrl = "https://maps.googleapis.com/maps/api/staticmap?center=\(loc.coordinate.latitude),\(loc.coordinate.longitude)&zoom=19&size=600x400&maptype=satellite&markers=color:red%7Clabel:A%7C\(loc.coordinate.latitude),\(loc.coordinate.longitude)&key=\(googleMapsApiKey)"
        var address = gpsString
        let notes = composeNotes(from: appointment, gpsString: gpsString, mapUrl: mapUrl)
        if let appt = appointment, let apptAddr = appt.propertyAddress, !apptAddr.isEmpty {
            address = apptAddr
        }
        self.lastMapUrl = mapUrl
        self.lastStaticMapUrl = staticMapUrl
        isSending = true
        notificationService.sendNoonlightPanicAlert(
            userId: agentId,
            location: loc.coordinate,
            address: address,
            notes: notes
        ) { success, message in
            isSending = false
            alertSuccess = success
            alertMessage = message ?? (success ? "Emergency alert sent successfully." : "Unknown error.")
            alertShown = true
        }
    }

    private func fetchCurrentAppointment(at date: Date) -> AppointmentEntity? {
        let request = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
        request.predicate = NSPredicate(format: "startTime <= %@ AND endTime >= %@", date as NSDate, date as NSDate)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request))?.first
    }

    private func extractUnit(from address: String?) -> String? {
        guard let address = address else { return nil }
        let patterns = [
            "#\\s?([A-Za-z0-9-]+)", // #12B
            "Apt\\.?\\s?([A-Za-z0-9-]+)", // Apt 5
            "Suite\\s?([A-Za-z0-9-]+)", // Suite 210
            "Unit\\s?([A-Za-z0-9-]+)" // Unit 3A
        ]
        for pattern in patterns {
            if let match = address.range(of: pattern, options: .regularExpression) {
                return String(address[match])
            }
        }
        return nil
    }

    private func composeNotes(from appointment: AppointmentEntity?, gpsString: String, mapUrl: String) -> String {
        var notes = "Agent triggered panic alert.\nGPS: \(gpsString)\nMap: \(mapUrl)"
        if let appt = appointment {
            if let apptAddr = appt.propertyAddress, !apptAddr.isEmpty {
                notes += "\nAppointment Address: \(apptAddr)"
                if let unit = extractUnit(from: apptAddr) {
                    notes += "\nUnit: \(unit)"
                }
            }
            if let title = appt.title, !title.isEmpty {
                notes += "\nTitle: \(title)"
            }
            if let status = appt.status, !status.isEmpty {
                notes += "\nStatus: \(status)"
            }
            if let id = appt.eventIdentifier, !id.isEmpty {
                notes += "\nEvent ID: \(id)"
            }
        }
        return notes
    }
}

// Simple CLLocationManager wrapper for SwiftUI
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}
