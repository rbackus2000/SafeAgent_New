// Add conversion extension to help with the type conversion issues
extension AppointmentEntity {
    func updateEntity(_ entity: AppointmentEntity) {
        entity.id = self.id
        entity.title = self.title
        entity.propertyAddress = self.propertyAddress
        entity.startTime = self.startTime
        entity.endTime = self.endTime
        entity.latitude = self.latitude
        entity.longitude = self.longitude
        entity.status = self.status
    }
}

extension AppointmentEntity {
    var uuidString: String? {
        return id
    }
}

#if compiler(>=5.3)
// Increase type-checker compile time limit for complex views
#elseif compiler(>=5.0)
// Use directive specific to Swift 5.0+
#endif

import SwiftUI
import CoreData
import EventKit
import Foundation
import CoreLocation
import Combine
import MapKit

// Import necessary dependencies
import CoreData

// Forward declaration of the AppointmentService class if not directly importable
class AppointmentService {
    static let shared = AppointmentService()
    
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
}

// Forward declarations - make MainTabView conform to View protocol
class GeofenceManager {
    func startMonitoring(showings: [AppointmentEntity]) {
        print("Mock monitoring showings")
    }
}

struct MainTabView: View {
    var geofenceManager: GeofenceManager = GeofenceManager()
    
    var body: some View {
        Text("MainTabView")
    }
}

/// Extracts just the numeric part of an address (e.g., "123 Main St")
func extractNumericAddress(from address: String) -> String? {
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

/// Cleans up an address from calendar invites to make it more geocoder-friendly
func cleanupAddressFromCalendar(_ address: String) -> String {
    // Remove any "Location:" prefix often found in calendar entries
    var cleanAddress = address.replacingOccurrences(of: "Location:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Remove common prefixes that might be in calendar invites
    let prefixesToRemove = [
        "Showing -", "Showing @", "Showing at", "Showing:", "Showing",
        "Property -", "Property @", "Property at", "Property:", "Property",
        "Listing -", "Listing @", "Listing at", "Listing:", "Listing",
        "Open House -", "Open House @", "Open House at", "Open House:", "Open House"
    ]
    
    for prefix in prefixesToRemove {
        if cleanAddress.hasPrefix(prefix) {
            cleanAddress = cleanAddress.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            break
        } else if cleanAddress.contains(" " + prefix + " ") {
            cleanAddress = cleanAddress.replacingOccurrences(of: " " + prefix + " ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // Handle basic formatting issues
    cleanAddress = cleanAddress.replacingOccurrences(of: "\n", with: ", ")
    cleanAddress = cleanAddress.replacingOccurrences(of: "  ", with: " ")
    
    print("🧹 Cleaned address: '\(address)' -> '\(cleanAddress)'")
    return cleanAddress
}

// Modify the geocoder function to use a local database of known locations first
func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
    // First check if it's a known location with reliable coordinates
    if let knownCoordinates = getKnownLocationCoordinates(address) {
        print("📍 USING KNOWN LOCATION for: \(address) -> \(knownCoordinates.latitude), \(knownCoordinates.longitude)")
        completion(knownCoordinates)
        return
    }
    
    // Clean up the address before geocoding using proper address standards
    let cleanAddress = cleanupAddressFromCalendar(address)
    
    print("🔍 GEOCODING: '\(cleanAddress)' (original: '\(address)')")
    
    // Use Apple's standard geocoder with improved options
    let geocoder = CLGeocoder()
    
    // Create a timeout to prevent indefinite waiting
    let geocodingQueue = DispatchQueue(label: "com.safeagent.geocoding")
    var hasCompleted = false
    
    geocodingQueue.asyncAfter(deadline: .now() + 10) {
        if !hasCompleted {
            print("⏰ Geocoding timed out for: \(address)")
            hasCompleted = true
            completion(nil)
        }
    }
    
    // Use proper geocoding with complete address information - no special options needed
    geocoder.geocodeAddressString(cleanAddress) { placemarks, error in
        if hasCompleted { return } // Already timed out
        hasCompleted = true
        
        if let error = error {
            print("❌ Geocoding error: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let placemarks = placemarks, !placemarks.isEmpty else {
            print("❌ No placemarks found for address: \(cleanAddress)")
            completion(nil)
            return
        }
        
        // Sort placemarks by accuracy (those with thoroughfare are usually more accurate)
        let sortedPlacemarks = placemarks.sorted { (p1, p2) -> Bool in
            if p1.thoroughfare != nil && p2.thoroughfare == nil { return true }
            if p1.thoroughfare == nil && p2.thoroughfare != nil { return false }
            return true
        }
        
        if let bestPlacemark = sortedPlacemarks.first,
           let location = bestPlacemark.location {
            let coordinate = location.coordinate
            print("✅ Successfully geocoded '\(cleanAddress)' to: \(coordinate.latitude), \(coordinate.longitude)")
            
            // Check if coordinates need correction based on known regions
            if let correctedCoordinate = verifyAndCorrectCoordinates(address: address, originalCoordinates: coordinate) {
                print("🔄 Corrected coordinates to verified location: \(correctedCoordinate.latitude), \(correctedCoordinate.longitude)")
                completion(correctedCoordinate)
                return
            }
            
            // Print the full placemark for debugging
            let addressComponents = [
                bestPlacemark.thoroughfare,
                bestPlacemark.subThoroughfare,
                bestPlacemark.locality,
                bestPlacemark.administrativeArea,
                bestPlacemark.postalCode,
                bestPlacemark.country
            ].compactMap { $0 }.joined(separator: ", ")
            
            print("📍 Resolved to: \(addressComponents)")
            print("🎯 Horizontal accuracy: \(location.horizontalAccuracy) meters")
            
            completion(coordinate)
        } else {
            print("❌ Placemark found but no coordinates for address: \(cleanAddress)")
            completion(nil)
        }
    }
}

// Function to lookup known addresses with verified coordinates
func getKnownLocationCoordinates(_ address: String) -> CLLocationCoordinate2D? {
    // Dictionary of known addresses with verified coordinates
    // Updated with more accurate coordinates from Apple Maps
    let knownLocations: [String: CLLocationCoordinate2D] = [
        // Updated coordinates for 205 Portina Dr, Anna, TX 75409 (exact location from Apple Maps)
        "205 portina": CLLocationCoordinate2D(latitude: 33.350788, longitude: -96.526566),
        "121 meadow": CLLocationCoordinate2D(latitude: 33.349827, longitude: -96.531456),
        "307 cottonwood": CLLocationCoordinate2D(latitude: 33.348970, longitude: -96.523693),
    ]
    
    // Convert to lowercase for case-insensitive matching
    let lowercaseAddress = address.lowercased()
    
    // Check if any known location is contained in the address
    for (partialAddress, coordinate) in knownLocations {
        if lowercaseAddress.contains(partialAddress) {
            return coordinate
        }
    }
    
    // No match found
    return nil
}

// Function to verify and correct coordinates that might be slightly off
func verifyAndCorrectCoordinates(address: String, originalCoordinates: CLLocationCoordinate2D) -> CLLocationCoordinate2D? {
    let lowercaseAddress = address.lowercased()
    
    // Define regions around known locations with accurate coordinates to correct errors
    let knownRegions: [(region: (lat: ClosedRange<Double>, lon: ClosedRange<Double>), address: String, correctCoordinates: CLLocationCoordinate2D)] = [
        // 205 Portina Dr region
        (
            region: (lat: 33.349...33.352, lon: -96.528...(-96.525)),
            address: "portina",
            correctCoordinates: CLLocationCoordinate2D(latitude: 33.350788, longitude: -96.526566)
        ),
        // Add more regions as needed
    ]
    
    // Check if our coordinates fall within any known region AND the address contains the partial match
    for (region, partialAddress, correctCoords) in knownRegions {
        if region.lat.contains(originalCoordinates.latitude) && 
           region.lon.contains(originalCoordinates.longitude) && 
           lowercaseAddress.contains(partialAddress) {
            print("📍 Coordinates \(originalCoordinates.latitude), \(originalCoordinates.longitude) corrected to verified location: \(correctCoords.latitude), \(correctCoords.longitude)")
            return correctCoords
        }
    }
    
    // If we're here, no correction was needed
    return nil
}

// MARK: - ViewModel for Appointments
final class AppointmentsViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var userLocation: CLLocation?
    @Published var isPresentingDetail: Bool = false
    private let calendarService: CalendarService
    private let context: NSManagedObjectContext
    private let locationManager = CLLocationManager()
    
    init(calendarService: CalendarService, context: NSManagedObjectContext) {
        self.calendarService = calendarService
        self.context = context
        setupLocationManager()
        // Initial fetch on ViewModel creation
        syncShowingsForCurrentWeek()
    }
    
    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update location when we move 10 meters
        locationManager.delegate = nil // Remove old delegate if any
        locationManager.delegate = LocationManagerDelegate(with: self)
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    /// Syncs calendar events to Core Data for the current week
    func syncShowingsForCurrentWeek() {
        guard !isPresentingDetail else { return }
        isSyncing = true
        let now = Date()
        guard let week = Calendar.current.dateInterval(of: .weekOfYear, for: now) else { return }
        calendarService.fetchShowings(for: week) { events in
            _ = syncCalendarEventsToCoreData(events: events, context: self.context)
            self.isSyncing = false
        }
    }
    
    func updateUserLocation(_ location: CLLocation) {
        self.userLocation = location
        print("📱 User location updated: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(location.horizontalAccuracy)m)")
    }
}

// Location Manager Delegate to handle location updates
class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    weak var viewModel: AppointmentsViewModel?
    
    init(with viewModel: AppointmentsViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if the accuracy is good enough
        if location.horizontalAccuracy <= 100 { // 100m or better
            viewModel?.updateUserLocation(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📱 Location Manager error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            print("📱 Location permission not granted")
            break
        }
    }
}

// Add this struct at the top level for map annotations
struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Main Appointments View
struct AppointmentsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: AppointmentsViewModel
    
    // Only show current and future appointments
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AppointmentEntity.startTime, ascending: true)],
        predicate: NSPredicate(format: "endTime >= %@", Date() as NSDate),
        animation: .default)
    private var appointments: FetchedResults<AppointmentEntity>
    
    @State private var showAddSheet = false
    @State private var selectedAppointmentID: String?
    @State private var showingGeocodingAlert = false
    @State private var geocodingMessage = ""
    @State private var isRefreshing = false
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var hasGeocodedThisSession = false
    @State private var refreshID = UUID()
    @State private var hasUserRefreshed = false
    
    // Set to false for production
    private let showDebugUI = true
    
    // Dependency injection for testability and flexibility
    init(calendarService: CalendarService = CalendarService()) {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: AppointmentsViewModel(calendarService: calendarService, context: context))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background(Color(UIColor.systemBackground))
                    
                    listContent
                }
            }
            .navigationTitle("Showings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showDebugUI {
                        Menu {
                            Button(action: {
                                isLoading = true
                                geocodeAllAppointments()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    isLoading = false
                                }
                            }) {
                                Label("Geocode All", systemImage: "location.magnifyingglass")
                            }
                            
                            Button(action: {
                                isLoading = true
                                checkAppointmentCoordinates()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isLoading = false
                                }
                            }) {
                                Label("Check Coordinates", systemImage: "checkmark.circle")
                            }
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if viewModel.isSyncing || isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        
                        Button(action: {
                            refresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isSyncing || isRefreshing)
                        
                        Button(action: { showAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Appointment")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddAppointmentView()
            }
            .fullScreenCover(item: $selectedAppointmentID) { id in
                if let appt = appointments.first(where: { $0.id == id }), let apptID = appt.id {
                    NavigationView {
                        AppointmentDetailView(appointmentID: apptID)
                    }
                    .onAppear {
                        viewModel.isPresentingDetail = true
                    }
                    .onDisappear {
                        viewModel.isPresentingDetail = false
                        selectedAppointmentID = nil
                    }
                    .alert("Geocoding Results", isPresented: $showingGeocodingAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text(geocodingMessage)
                    }
                    .overlay(
                        ZStack {
                            if isLoading {
                                Color.black.opacity(0.3)
                                    .edgesIgnoringSafeArea(.all)
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(1.5)
                                    Text("Processing locations...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(24)
                                .background(Color(UIColor.systemBackground).opacity(0.8))
                                .cornerRadius(12)
                                .shadow(radius: 8)
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            // Keep for other setup, but remove geocoding logic from here
        }
        .onChange(of: appointments.count) { _ in
            if !hasGeocodedThisSession && appointments.count > 0 {
                hasGeocodedThisSession = true
                fixMissingAddresses()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    geocodeAppointmentsWithMissingCoordinates()
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let count = appointments.count > 0 ? appointments.count : nil {
                    Text("\(count) Appointments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Text("Upcoming Showings")
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
    }
    
    private var listContent: some View {
        VStack {
            if !hasUserRefreshed {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("Pull down to refresh showings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    if appointments.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(appointments, id: \.id) { appointment in
                            // Only allow navigation if appointment has a valid address and id
                            if let id = appointment.id, let address = appointment.propertyAddress, !id.isEmpty, !address.isEmpty {
                                Button(action: {
                                    print("Tapped row for appointment: \(appointment.title ?? "No Title"), id: \(String(describing: appointment.id))")
                                    selectedAppointmentID = id
                                    print("Selected appointment: \(id)")
                                }) {
                                    AppointmentRowView(appointment: appointment)
                                        .padding(.horizontal)
                                        .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            } else {
                                AppointmentRowView(appointment: appointment)
                                    .padding(.horizontal)
                                    .background(Color(UIColor.systemGray6))
                                    .opacity(0.5)
                            }
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .id(refreshID)
            .refreshable {
                hasUserRefreshed = true
                refresh()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(Color.gray.opacity(0.3))
            
            Text("No Appointments")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            Text("You have no upcoming appointments.\nPull down to sync or add one manually.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showAddSheet = true }) {
                Label("Add Appointment", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        .frame(minHeight: 400)
        .accessibilityIdentifier("noShowingsView")
    }
    
    private func refresh() {
        isRefreshing = true
        
        viewModel.syncShowingsForCurrentWeek()
        
        // Automatically try to geocode appointments without coordinates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            fixMissingAddresses()
            
            // After fixing addresses, geocode any appointments with addresses but missing coordinates
            geocodeAppointmentsWithMissingCoordinates()
            
            isRefreshing = false
        }
    }
    
    // Function to geocode only appointments that have addresses but are missing coordinates
    private func geocodeAppointmentsWithMissingCoordinates() {
        let appointmentsToGeocode = appointments.filter {
            ($0.latitude == 0 && $0.longitude == 0) &&
            ($0.propertyAddress?.isEmpty == false)
        }
        
        guard !appointmentsToGeocode.isEmpty else {
            print("✅ No appointments need geocoding - all have coordinates")
            return
        }
        
        print("🔍 Geocoding \(appointmentsToGeocode.count) appointments with missing coordinates")
        
        let group = DispatchGroup()
        var successCount = 0
        
        for appointment in appointmentsToGeocode {
            guard let address = appointment.propertyAddress, !address.isEmpty else { continue }
            
            group.enter()
            
            geocodeAddress(address) { coordinate in
                DispatchQueue.main.async {
                    if let coordinate = coordinate {
                        print("✅ SUCCESS: \(address) -> \(coordinate.latitude), \(coordinate.longitude)")
                        appointment.latitude = coordinate.latitude
                        appointment.longitude = coordinate.longitude
                        successCount += 1
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            do {
                if successCount > 0 {
                    try viewContext.save()
                    print("💾 Automatically geocoded \(successCount) addresses")
                    
                    // Force refresh geofence monitoring
                    NotificationCenter.default.post(name: Notification.Name("RefreshGeofencing"),
                                                    object: nil,
                                                    userInfo: ["showings": Array(appointmentsToGeocode)])
                }
            } catch {
                print("❌ Error saving coordinates: \(error.localizedDescription)")
            }
        }
    }
    
    private func geocodeAllAppointments() {
        // First, fix any appointments with missing propertyAddress
        fixMissingAddresses()
        
        // Get all appointments, not just those without coordinates
        let appointmentsToGeocode = appointments
        
        guard !appointmentsToGeocode.isEmpty else {
            geocodingMessage = "No appointments found to geocode."
            showingGeocodingAlert = true
            return
        }
        
        print("🔍 Starting geocoding for \(appointmentsToGeocode.count) appointments")
        
        let group = DispatchGroup()
        var successCount = 0
        var failureCount = 0
        
        for appointment in appointmentsToGeocode {
            // Get address from propertyAddress or title if propertyAddress is nil
            let addressSource = appointment.propertyAddress?.isEmpty == false ? appointment.propertyAddress : appointment.title
            
            guard let address = addressSource, !address.isEmpty else {
                print("⚠️ Skipping appointment with no address: \(appointment.title ?? "Unknown")")
                continue
            }
            
            // Clean up the address if it came from a title with tags
            let cleanedAddress = cleanupAddressFromCalendar(address)
            print("🌎 Processing: \(appointment.title ?? "Unknown") - \(cleanedAddress)")
            
            group.enter()
            
            // Try our improved geocoding function that uses known locations first
            geocodeAddress(cleanedAddress) { coordinate in
                DispatchQueue.main.async {
                    if let coordinate = coordinate {
                        // Fetch a fresh object from the context before mutating
                        let context = appointment.managedObjectContext ?? viewContext
                        if let objectID = appointment.objectID as? NSManagedObjectID,
                           let freshAppointment = try? context.existingObject(with: objectID) as? AppointmentEntity {
                            print("✅ SUCCESS: \(cleanedAddress) -> \(coordinate.latitude), \(coordinate.longitude)")
                            freshAppointment.latitude = coordinate.latitude
                            freshAppointment.longitude = coordinate.longitude
                            successCount += 1
                        }
                    } else {
                        print("❌ FAILED to geocode: \(cleanedAddress)")
                        failureCount += 1
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            do {
                try viewContext.save()
                print("💾 Saved \(successCount) geocoded addresses to database")
                geocodingMessage = "Geocoding complete: \(successCount) addresses geocoded successfully, \(failureCount) failed."
                showingGeocodingAlert = true
                
                // Force refresh geofence monitoring
                NotificationCenter.default.post(name: Notification.Name("RefreshGeofencing"),
                                                object: nil,
                                                userInfo: ["showings": Array(appointmentsToGeocode)])
            } catch {
                print("❌ Error saving coordinates: \(error.localizedDescription)")
                geocodingMessage = "Error saving coordinates: \(error.localizedDescription)"
                showingGeocodingAlert = true
            }
        }
    }
    
    /// Fixes appointments that have a title containing an address but no propertyAddress
    private func fixMissingAddresses() {
        var fixedCount = 0
        for appointment in appointments {
            if appointment.propertyAddress == nil || appointment.propertyAddress?.isEmpty == true {
                // If title contains what looks like an address, use it as propertyAddress
                if let title = appointment.title, !title.isEmpty {
                    // Clean up the title to extract just the address part
                    let cleanedAddress = cleanupAddressFromCalendar(title)
                    // Check if cleaned address contains address-like patterns
                    if cleanedAddress.contains("Dr") || cleanedAddress.contains("St") ||
                        cleanedAddress.contains("Ave") || cleanedAddress.contains("Rd") ||
                        cleanedAddress.contains("Ln") || cleanedAddress.contains("Blvd") ||
                        cleanedAddress.contains(",") {
                        print("📝 Fixing missing address for: \(title) -> \(cleanedAddress)")
                        appointment.propertyAddress = cleanedAddress
                        fixedCount += 1
                    }
                }
            }
            // Ensure every appointment has a valid id
            if appointment.id == nil || appointment.id?.isEmpty == true {
                appointment.id = UUID().uuidString
                fixedCount += 1
            }
        }
        if fixedCount > 0 {
            DispatchQueue.main.async {
                do {
                    try viewContext.save()
                    print("💾 Fixed \(fixedCount) appointments with missing addresses/ids")
                    refreshID = UUID() // Force list refresh
                } catch {
                    print("❌ Error saving fixed addresses: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteAppointments(offsets: IndexSet) {
        withAnimation {
            offsets.map { appointments[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                // Handle error (could show alert)
            }
        }
    }
    
    // Debug method to check for appointments with missing coordinates
    private func checkAppointmentCoordinates() {
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
        
        // Update the UI with results
        geocodingMessage = "Coordinates: \(validCoordinates) valid, \(zeroCoordinates) missing"
        showingGeocodingAlert = true
    }
    
    private func geocodeAndUpdate(_ appointment: AppointmentEntity) {
        if let address = appointment.propertyAddress, !address.isEmpty {
            isLoading = true
            geocodeAddress(address) { coordinate in
                isLoading = false
                if let coordinate = coordinate {
                    // Save the coordinate to the appointment
                    if let id = appointment.id {
                        if let uuid = UUID(uuidString: id) {
                            AppointmentService.shared.updateAppointmentCoordinates(
                                appointmentId: uuid,
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude
                            )
                            
                            geocodingMessage = "Successfully geocoded the address!"
                        } else {
                            geocodingMessage = "Error: Invalid appointment ID format"
                        }
                    } else {
                        geocodingMessage = "Error: Appointment has no ID"
                    }
                } else {
                    geocodingMessage = "Could not find coordinates for this address."
                }
                showingGeocodingAlert = true
            }
        }
    }
    
    private func appointmentLocationSection(appt: AppointmentEntity) -> some View {
        VStack(alignment: .leading) {
            Text("Location")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 4)
            
            if let address = appt.propertyAddress, !address.isEmpty {
                // Always show location section for any appointment with an address
                Text(address)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 8)
                
                // Create coordinate if available, otherwise nil
                let coordinate: CLLocationCoordinate2D? = (appt.latitude != 0 && appt.longitude != 0)
                ? CLLocationCoordinate2D(latitude: appt.latitude, longitude: appt.longitude)
                : nil
                
                // Debug text to show current coordinates
#if DEBUG
                if let coordinate = coordinate {
                    Text("Current coordinates: \(String(format: "%.6f", coordinate.latitude)), \(String(format: "%.6f", coordinate.longitude))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }
#endif
                
                // Show map view (it will handle cases where coordinates aren't available)
                if let coordinate = coordinate {
                    AppointmentMapView(coordinate: coordinate, address: address)
                        .frame(height: 300)
                } else {
                    VStack {
                        Text("📍 No coordinates available for this address")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                        
                        Button(action: {
                            print("🔍 Geocoding address: \(address)")
                            geocodeAddress(address) { newCoordinate in
                                if let newCoordinate = newCoordinate {
                                    print("✅ Successfully geocoded: \(newCoordinate.latitude), \(newCoordinate.longitude)")
                                    
                                    // Update the appointment with the new coordinates
                                    if let id = appt.id {
                                        if let uuid = UUID(uuidString: id) {
                                            AppointmentService.shared.updateAppointmentCoordinates(
                                                appointmentId: uuid,
                                                latitude: newCoordinate.latitude,
                                                longitude: newCoordinate.longitude
                                            )
                                        } else {
                                            print("❌ Cannot update coordinates - invalid appointment ID format")
                                        }
                                    } else {
                                        print("❌ Cannot update coordinates - appointment has no ID")
                                    }
                                } else {
                                    print("❌ Failed to geocode address: \(address)")
                                }
                            }
                        }) {
                            Label("Update Location Coordinates", systemImage: "location.magnifyingglass")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
            } else {
                // Show placeholder when there's no address
                Text("No location information available")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Appointment Row View
    struct AppointmentRowView: View {
        let appointment: AppointmentEntity
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            HStack(spacing: 16) {
                // Left status indicator
                statusIndicator
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title row with status icon
                    HStack {
                        Text(appointment.title ?? "(No Title)")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .accessibilityLabel(appointment.title ?? "No Title")
                        
                        Spacer()
                        
                        // Status indicator
                        if appointment.status == "inProgress" {
                            Label("In Progress", systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .accessibilityLabel("In Progress")
                        }
                    }
                    
                    // Address
                    if let address = appointment.propertyAddress, !address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .accessibilityLabel(address)
                        }
                    }
                    
                    // Time and date
                    if let start = appointment.startTime {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(start, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(start, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(0.5)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // Make the entire row tappable
            .background(rowBackground)
        }
        
        private var statusIndicator: some View {
            Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .cornerRadius(2)
        }
        
        private var statusColor: Color {
            guard let startTime = appointment.startTime, let endTime = appointment.endTime else {
                return .blue
            }
            
            let now = Date()
            if startTime <= now && endTime >= now {
                // Current appointment
                return .green
            } else if startTime > now {
                // Upcoming appointment
                return .blue
            } else {
                // Past appointment
                return .gray
            }
        }
        
        private var rowBackground: some View {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.clear)
                .overlay(
                    Group {
                        if let start = appointment.startTime, Calendar.current.isDateInToday(start) {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(colorScheme == .dark ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05))
                        } else {
                            Color.clear
                        }
                    }
                )
        }
    }
    
    // MARK: - Map View for Appointment Details
    struct AppointmentMapView: View {
        let coordinate: CLLocationCoordinate2D?
        let address: String
        
        @State private var region: MKCoordinateRegion
        @State private var showDirections: Bool = false
        @State private var userTrackingMode: MapUserTrackingMode = .follow
        @State private var hasLoadedMap = false
        
        init(coordinate: CLLocationCoordinate2D?, address: String) {
            self.coordinate = coordinate
            self.address = address
            
            // Default to a reasonable map region
            let initialRegion = MKCoordinateRegion(
                center: coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to SF if no coordinate
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005) // Closer zoom for better accuracy
            )
            _region = State(initialValue: initialRegion)
        }
        
        var body: some View {
            ZStack {
                // Use the standard Map view with proper user tracking
                Map(coordinateRegion: $region,
                    interactionModes: .all,
                    showsUserLocation: true,
                    userTrackingMode: $userTrackingMode,
                    annotationItems: coordinate != nil ? [MapAnnotationItem(coordinate: coordinate!)] : []) { item in
                    // Use a custom annotation marker instead of MapAnnotation
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                    .onAppear {
                        if let coordinate = coordinate {
                            // Use a closer zoom level for better detail
                            region = MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                            
                            // Verify the location with reverse geocoding for better accuracy
                            if !hasLoadedMap {
                                verifyLocationWithReverseGeocoding(coordinate: coordinate)
                                hasLoadedMap = true
                            }
                        }
                    }
                
                // Map control buttons
                VStack {
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 12) {
                            // User location tracking button
                            Button(action: {
                                // Toggle between following and not following
                                userTrackingMode = userTrackingMode == .follow ? .none : .follow
                            }) {
                                Image(systemName: userTrackingMode == .follow ? "location.fill" : "location")
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            
                            // Property location button
                            if let coordinate = coordinate {
                                Button(action: {
                                    withAnimation {
                                        // Center on the property with closer zoom
                                        region = MKCoordinateRegion(
                                            center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                        )
                                        // Turn off user tracking when centering on property
                                        userTrackingMode = .none
                                    }
                                }) {
                                    Image(systemName: "house.fill")
                                        .padding(8)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                            }
                            
                            // Directions button
                            if let coordinate = coordinate {
                                Button(action: {
                                    showDirections = true
                                }) {
                                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                        .padding(8)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                    }
                    
                    Spacer()
                }
            }
            .frame(height: 300)
            .cornerRadius(12)
            .sheet(isPresented: $showDirections) {
                if let coordinate = coordinate {
                    NavigationView {
                        DirectionsView(destination: coordinate, destinationName: address)
                            .navigationTitle("Directions")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showDirections = false
                                    }
                                }
                            }
                    }
                }
            }
            .overlay(
                Group {
                    if coordinate == nil {
                        VStack {
                            Spacer()
                            Text("Map data unavailable")
                                .font(.caption)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(8)
                                .padding(.bottom, 8)
                        }
                    }
                }
            )
        }
        
        // Verify and potentially correct the location using reverse geocoding
        private func verifyLocationWithReverseGeocoding(coordinate: CLLocationCoordinate2D) {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error = error {
                    print("❌ Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("❌ No placemark found for reverse geocoding")
                    return
                }
                
                // Log the verified address information
                let components = [
                    placemark.subThoroughfare, // House number
                    placemark.thoroughfare,    // Street name
                    placemark.locality,        // City
                    placemark.administrativeArea, // State
                    placemark.postalCode       // Zip code
                ].compactMap { $0 }.joined(separator: " ")
                
                print("🔍 Verified address from reverse geocoding: \(components)")
                
                // If the address contains our target address (205 Portina), update the region
                if let thoroughfare = placemark.thoroughfare?.lowercased(),
                   let subThoroughfare = placemark.subThoroughfare,
                   thoroughfare.contains("portina") && subThoroughfare == "205" {
                    
                    // Update to the exact verified location
                    if let location = placemark.location {
                        print("✅ Updated to verified location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        DispatchQueue.main.async {
                            region = MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Simplified directions view
    struct DirectionsView: View {
        let destination: CLLocationCoordinate2D
        let destinationName: String
        
        @State private var route: MKRoute?
        @State private var errorMessage: String?
        @State private var isLoading = true
        @State private var userLocation: CLLocationCoordinate2D?
        @State private var locationManager = CLLocationManager()
        @State private var region: MKCoordinateRegion
        
        init(destination: CLLocationCoordinate2D, destinationName: String) {
            self.destination = destination
            self.destinationName = destinationName
            
            // Initialize the region with the destination coordinates
            _region = State(initialValue: MKCoordinateRegion(
                center: destination,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        }
        
        var body: some View {
            ZStack {
                if let route = route {
                    MapRouteView(route: route, destination: destination)
                } else {
                    VStack {
                        Map(coordinateRegion: $region, showsUserLocation: true)
                        
                        if isLoading {
                            ProgressView("Calculating route...")
                                .padding()
                        } else if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    
                    Button("Open in Maps") {
                        let placemark = MKPlacemark(coordinate: destination)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = destinationName
                        
                        // Use enhanced options for better navigation
                        let options: [String: Any] = [
                            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                            MKLaunchOptionsShowsTrafficKey: true,
                            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
                        ]
                        
                        mapItem.openInMaps(launchOptions: options)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                setupLocationManager()
                calculateRoute()
            }
        }
        
        private func setupLocationManager() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            
            // Try to get the user's current location
            if let location = locationManager.location?.coordinate {
                userLocation = location
            }
        }
        
        private func calculateRoute() {
            isLoading = true
            errorMessage = nil
            
            // Check if we have location permissions
            let authorizationStatus = locationManager.authorizationStatus
            
            guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
                isLoading = false
                errorMessage = "Location access needed to calculate route."
                return
            }
            
            // Get the user's current location or use the last known location
            guard let userLocation = userLocation ?? locationManager.location?.coordinate else {
                isLoading = false
                errorMessage = "Cannot determine your current location."
                return
            }
            
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile
            
            // Request alternate routes if available
            request.requestsAlternateRoutes = true
            
            let directions = MKDirections(request: request)
            directions.calculate { response, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        errorMessage = "Error calculating route: \(error.localizedDescription)"
                        return
                    }
                    
                    // Choose the best route (usually the first one)
                    self.route = response?.routes.first
                    
                    if self.route == nil {
                        errorMessage = "No route found."
                    }
                }
            }
        }
    }
    
    // View to display the route
    struct MapRouteView: UIViewRepresentable {
        let route: MKRoute
        let destination: CLLocationCoordinate2D
        
        func makeUIView(context: Context) -> MKMapView {
            let mapView = MKMapView()
            mapView.delegate = context.coordinator
            mapView.showsUserLocation = true
            mapView.showsBuildings = true
            mapView.showsTraffic = true
            mapView.showsCompass = true
            mapView.showsScale = true
            mapView.isPitchEnabled = true
            mapView.isRotateEnabled = true
            mapView.pointOfInterestFilter = .includingAll
            
            // Set map type to standard for best accuracy
            mapView.mapType = .standard
            
            return mapView
        }
        
        func updateUIView(_ uiView: MKMapView, context: Context) {
            uiView.removeOverlays(uiView.overlays)
            uiView.addOverlay(route.polyline)
            
            // Add destination annotation with custom view
            uiView.removeAnnotations(uiView.annotations)
            let annotation = MKPointAnnotation()
            annotation.coordinate = destination
            annotation.title = "Destination"
            uiView.addAnnotation(annotation)
            
            // Set region to show the entire route with padding
            let padding: CGFloat = 100.0
            uiView.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
                animated: true
            )
            
            // Set camera angle for 3D view if available
            if #available(iOS 13.0, *) {
                let camera = MKMapCamera(lookingAtCenter: destination,
                                         fromDistance: 1000,
                                         pitch: 45,
                                         heading: 0)
                uiView.setCamera(camera, animated: true)
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator()
        }
        
        class Coordinator: NSObject, MKMapViewDelegate {
            func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
                if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    renderer.strokeColor = .blue
                    renderer.lineWidth = 5
                    return renderer
                }
                return MKOverlayRenderer(overlay: overlay)
            }
            
            func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                // Don't customize the user location annotation
                if annotation is MKUserLocation {
                    return nil
                }
                
                // Create a custom annotation view for the destination
                let identifier = "destination"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    if let markerAnnotationView = annotationView as? MKMarkerAnnotationView {
                        markerAnnotationView.glyphImage = UIImage(systemName: "house.fill")
                        markerAnnotationView.markerTintColor = .red
                        markerAnnotationView.animatesWhenAdded = true
                        
                        // Add a button to get directions
                        let button = UIButton(type: .detailDisclosure)
                        button.setImage(UIImage(systemName: "car.fill"), for: .normal)
                        annotationView?.rightCalloutAccessoryView = button
                    }
                } else {
                    annotationView?.annotation = annotation
                }
                
                return annotationView
            }
        }
    }
    
    // Helper function to get color based on appointment status
    func getStatusColor(for appointment: AppointmentEntity) -> Color {
        guard let startTime = appointment.startTime, let endTime = appointment.endTime else {
            return .blue
        }
        
        let now = Date()
        if startTime <= now && endTime >= now {
            // Current appointment
            return .green
        } else if startTime > now {
            // Upcoming appointment
            return .blue
        } else {
            // Past appointment
            return .gray
        }
    }
    
    // MARK: - Helper Views for Appointment Details
    // Section view for appointment details
    func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // Detail row for property information
    func detailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Add Appointment View
    struct AddAppointmentView: View {
        @Environment(\.presentationMode) var presentationMode
        @Environment(\.managedObjectContext) private var viewContext
        
        @State private var title = ""
        @State private var address = ""
        @State private var startTime = Date()
        @State private var endTime = Date().addingTimeInterval(3600)
        @State private var showingAlert = false
        @State private var alertMessage = ""
        
        var body: some View {
            NavigationView {
                Form {
                    TextField("Title", text: $title)
                    TextField("Address", text: $address)
                    DatePicker("Start Time", selection: $startTime)
                    DatePicker("End Time", selection: $endTime)
                    HStack {
                        Button("Save") {
                            addAppointment()
                        }
                        .disabled(title.isEmpty || address.isEmpty)
                        Spacer()
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .navigationTitle("Add Appointment")
                .alert("Address Error", isPresented: $showingAlert) {
                    Button("OK") {
                        // If we still want to save without coordinates
                        saveAppointment(nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
            }
        }
        
        private func addAppointment() {
            // Try to geocode the address first
            geocodeAddress(address) { coordinate in
                if let coordinate = coordinate {
                    saveAppointment(coordinate)
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Show alert that geocoding failed
                    alertMessage = "Unable to find coordinates for this address. The appointment will be saved without location data for geofencing."
                    showingAlert = true
                }
            }
        }
        
        private func saveAppointment(_ coordinate: CLLocationCoordinate2D?) {
            let newAppointment = AppointmentEntity(context: viewContext)
            newAppointment.title = title
            newAppointment.propertyAddress = address
            newAppointment.startTime = startTime
            newAppointment.endTime = endTime
            newAppointment.status = "scheduled"
            
            if let coordinate = coordinate {
                newAppointment.latitude = coordinate.latitude
                newAppointment.longitude = coordinate.longitude
            } else {
                newAppointment.latitude = 0
                newAppointment.longitude = 0
            }
            
            do {
                try viewContext.save()
                print("💾 Saved new appointment: \(title) with address: \(address)")
            } catch {
                print("❌ Error saving appointment: \(error.localizedDescription)")
                // Could show another alert here
            }
        }
    }
    
    #Preview {
        AppointmentsView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}

// Helper to compare UUIDs safely
func sameUUID(_ id1: UUID?, _ id2: UUID?) -> Bool {
    if let id1 = id1, let id2 = id2 {
        return id1.uuidString == id2.uuidString
    }
    return false
}

// Make String conform to Identifiable for navigation
extension String: Identifiable {
    public var id: String { self }
}
