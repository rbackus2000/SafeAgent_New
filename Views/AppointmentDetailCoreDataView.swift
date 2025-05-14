import SwiftUI
import CoreData
import MapKit
import CoreLocation

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
func cleanupAddressFromCalendar(_ originalAddress: String) -> String {
    var address = originalAddress
    
    // Remove common prefixes that might be in calendar invites
    let prefixesToRemove = [
        "Showing -", "Showing @", "Showing at", "Showing:", "Showing",
        "Property -", "Property @", "Property at", "Property:", "Property",
        "Listing -", "Listing @", "Listing at", "Listing:", "Listing",
        "Open House -", "Open House @", "Open House at", "Open House:", "Open House"
    ]
    
    for prefix in prefixesToRemove {
        if address.hasPrefix(prefix) {
            address = address.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            break
        } else if address.contains(" " + prefix + " ") {
            address = address.replacingOccurrences(of: " " + prefix + " ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // Check if the address contains a city, state, zip
    // If not, we might want to append default values based on your typical location
    if !address.contains(",") {
        // This is a very simple address without city/state - could add default if needed
        // Example: address += ", Anna, TX 75409"
    }
    
    print("🧹 Cleaned address: '\(originalAddress)' -> '\(address)'")
    return address
}

struct AppointmentDetailCoreDataView: View {
    let appointment: AppointmentEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showingAddressAlert = false
    @State private var updatedAddress = ""
    @State private var showingUpdateConfirmation = false
    @State private var showingDebugInfo = false
    @State private var geocodingStatus = ""
    @State private var showingMapOptions = false
    
    // Set to false for production
    private let showDebugUI = true
    
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with property address and status
                headerSection
                
                // Property and appointment details
                VStack(spacing: 0) {
                    // Appointment time section
                    appointmentTimeSection
                    
                    // Property details section
                    propertyDetailsSection
                    
                    // Client information section
                    clientInfoSection
                    
                    // Agent information section
                    agentInfoSection
                    
                    // Notes section
                    notesSection
                    
                    // Actions section
                    actionsSection
                    
                    // Debug section (only in development)
                    if showDebugUI {
                        debugSection
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle("Showing Details", displayMode: .inline)
        .alert("Update Location", isPresented: $showingAddressAlert) {
            TextField("Address", text: $updatedAddress)
            
            Button("Update") {
                updateLocation()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter the full address to update location coordinates")
        }
        .alert("Location Updated", isPresented: $showingUpdateConfirmation) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("The location has been updated successfully.")
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Background
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.7),
                        Color.blue.opacity(0.6)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 200) // Increased height to accommodate status pill
                .edgesIgnoringSafeArea(.top)
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Status pill - moved to the top with more padding
                HStack {
                    Text(appointment.status ?? "Scheduled")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(20)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
                
                // Address
                Text(appointment.propertyAddress ?? "")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                
                // Title if different from address
                if let title = appointment.title, title != appointment.propertyAddress {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                // For time remaining, calculate directly here
                if let startTime = appointment.startTime {
                    let now = Date()
                    if startTime > now {
                        // Upcoming appointment
                        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: now, to: startTime)
                        if let days = components.day, days > 0 {
                            Text("in \(days) day\(days > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 4)
                        } else if let hours = components.hour, hours > 0 {
                            Text("in \(hours) hour\(hours > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 4)
                        } else if let minutes = components.minute {
                            Text("in \(minutes) minute\(minutes > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 4)
                        }
                    } else if let endTime = appointment.endTime, endTime > now {
                        // Current appointment
                        let components = Calendar.current.dateComponents([.hour, .minute], from: now, to: endTime)
                        if let hours = components.hour, hours > 0 {
                            Text("\(hours) hour\(hours > 1 ? "s" : "") left")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 4)
                        } else if let minutes = components.minute {
                            Text("\(minutes) minute\(minutes > 1 ? "s" : "") left")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16) // Add top padding to push content down
            .padding(.bottom, 20)
        }
    }
    
    private var appointmentTimeSection: some View {
        SectionView(title: "Appointment Time") {
            if let start = appointment.startTime, let end = appointment.endTime {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Start")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundColor(.green)
                        }
                        
                        Text(start, style: .date)
                            .font(.subheadline)
                        
                        Text(start, style: .time)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Label {
                            Text("End")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundColor(.red)
                        }
                        
                        Text(end, style: .date)
                            .font(.subheadline)
                        
                        Text(end, style: .time)
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                // Duration
                let duration = Calendar.current.dateComponents([.hour, .minute], from: start, to: end)
                if let hours = duration.hour, let minutes = duration.minute {
                    HStack {
                        Label {
                            Text("Duration: \(hours > 0 ? "\(hours)h " : "")\(minutes)m")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "hourglass")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var propertyDetailsSection: some View {
        SectionView(title: "Property Details") {
            // Since the MLS properties don't exist yet, we'll show a placeholder
            DetailRow(icon: "number", iconColor: .blue, title: "MLS #", value: "Not available")
            
            // For price, show a placeholder
            DetailRow(icon: "dollarsign.circle", iconColor: .green, title: "Listing Price", value: "Contact agent")
            
            // Property details placeholder
            DetailRow(icon: "house", iconColor: .blue, title: "Details", value: "Property details coming soon")
            
            Divider()
                .padding(.vertical, 8)
            
            // Property location and coordinates
            if appointment.latitude != 0 && appointment.longitude != 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Property Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(appointment.latitude, specifier: "%.6f"), \(appointment.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        openInMaps()
                    }) {
                        Text("View")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                .padding(.bottom, 8)
            }
            
            // Map button
            Button(action: {
                openInMaps()
            }) {
                Label("Open in Maps", systemImage: "map")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 4)
            
            // Additional direction buttons
            HStack(spacing: 12) {
                Button(action: {
                    openInGoogleMaps()
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Google Maps")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.45, green: 0.73, blue: 0.3))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    openInAppleMapsWithDirections()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                        Text("Directions")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var clientInfoSection: some View {
        SectionView(title: "Client Information") {
            HStack {
                Text("No client information")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    // Add client info action
                }) {
                    Text("Add")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var agentInfoSection: some View {
        SectionView(title: "Listing Information") {
            Text("No listing agent information")
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
    }
    
    private var notesSection: some View {
        SectionView(title: "Notes") {
            HStack {
                Text("No notes")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Spacer()
                
                Button(action: {
                    // Add notes action
                }) {
                    Text("Add")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 16) {
            // Safety check-in
            Button(action: {
                // Safety check-in action
            }) {
                Label("Safety Check-in", systemImage: "shield.checkmark.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            
            HStack(spacing: 16) {
                // Navigation button
                Button(action: {
                    navigateToAppointment()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.title2)
                        Text("Navigate")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .confirmationDialog("Choose Navigation App", isPresented: $showingMapOptions, titleVisibility: .visible) {
                    Button("Apple Maps") {
                        openInAppleMapsWithDirections()
                    }
                    
                    Button("Google Maps") {
                        openInGoogleMaps()
                    }
                    
                    Button("Cancel", role: .cancel) {}
                }
                
                // Add feedback
                Button(action: {
                    // Add feedback action
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                        Text("Add Feedback")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    private var debugSection: some View {
        SectionView(title: "Development Debug Tools", titleColor: .red) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        showingAddressAlert = true
                    }) {
                        Text("Update Address & Geocode")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        testGeofence()
                    }) {
                        Text("Test Geofence")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        forceGeocodeCurrentAppointment()
                    }) {
                        Text("Force Geocode")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Geocode status:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(geocodingStatus)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(4)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("ID: \(appointment.objectID.uriRepresentation().absoluteString)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Coords: \(appointment.latitude), \(appointment.longitude)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private struct SectionView<Content: View>: View {
        let title: String
        let content: Content
        var titleColor: Color = .primary
        
        init(title: String, titleColor: Color = .primary, @ViewBuilder content: () -> Content) {
            self.title = title
            self.titleColor = titleColor
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(titleColor)
                
                content
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
    
    private struct DetailRow: View {
        let icon: String
        let iconColor: Color
        let title: String
        let value: String
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Actions
    
    private func updateLocation() {
        geocodingStatus = "Geocoding..."
        
        geocodeAddress(updatedAddress) { coordinate in
            if let coordinate = coordinate {
                appointment.latitude = coordinate.latitude
                appointment.longitude = coordinate.longitude
                if appointment.propertyAddress != updatedAddress {
                    appointment.propertyAddress = updatedAddress
                }
                
                do {
                    try viewContext.save()
                    geocodingStatus = "Success! Coordinates updated."
                    showingUpdateConfirmation = true
                } catch {
                    print("Error updating location: \(error.localizedDescription)")
                    geocodingStatus = "Error: \(error.localizedDescription)"
                }
            } else {
                geocodingStatus = "Failed to geocode address"
            }
        }
    }
    
    private func forceGeocodeCurrentAppointment() {
        guard let address = appointment.propertyAddress, !address.isEmpty else {
            geocodingStatus = "No address to geocode"
            return
        }
        
        geocodingStatus = "Geocoding \(address)..."
        
        // Try direct geocoding with Google Maps API format
        let formattedAddress = address.replacingOccurrences(of: " ", with: "+")
        let googleStyleAddress = formattedAddress + "+USA"
        print("🔍 Trying Google-style address: \(googleStyleAddress)")
        
        geocodeAddress(googleStyleAddress) { coordinate in
            if let coordinate = coordinate {
                print("✅ SUCCESS with Google format: \(address) -> \(coordinate.latitude), \(coordinate.longitude)")
                appointment.latitude = coordinate.latitude
                appointment.longitude = coordinate.longitude
                saveCoordinates()
                geocodingStatus = "Success! Geocoded with Google format"
            } else {
                // Try with the original address
                geocodeAddress(address) { coordinate in
                    if let coordinate = coordinate {
                        print("✅ SUCCESS with original address: \(address) -> \(coordinate.latitude), \(coordinate.longitude)")
                        appointment.latitude = coordinate.latitude
                        appointment.longitude = coordinate.longitude
                        saveCoordinates()
                        geocodingStatus = "Success! Geocoded with original format"
                    } else {
                        // Try with just the numeric part
                        if let numericAddress = extractNumericAddress(from: address) {
                            geocodingStatus = "Trying numeric part: \(numericAddress)..."
                            print("🔍 Trying numeric part: \(numericAddress)")
                            
                            geocodeAddress(numericAddress) { coordinate in
                                if let coordinate = coordinate {
                                    print("✅ SUCCESS with numeric part: \(numericAddress) -> \(coordinate.latitude), \(coordinate.longitude)")
                                    appointment.latitude = coordinate.latitude
                                    appointment.longitude = coordinate.longitude
                                    saveCoordinates()
                                    geocodingStatus = "Success! Geocoded with numeric format"
                                } else {
                                    // Last resort: try with a hardcoded city/state
                                    let addressWithRegion = "\(numericAddress), Dallas, TX"
                                    geocodingStatus = "Last attempt with region: \(addressWithRegion)..."
                                    print("🔍 Last attempt with region: \(addressWithRegion)")
                                    
                                    geocodeAddress(addressWithRegion) { coordinate in
                                        if let coordinate = coordinate {
                                            print("✅ SUCCESS with region: \(addressWithRegion) -> \(coordinate.latitude), \(coordinate.longitude)")
                                            appointment.latitude = coordinate.latitude
                                            appointment.longitude = coordinate.longitude
                                            saveCoordinates()
                                            geocodingStatus = "Success! Geocoded with region"
                                        } else {
                                            print("❌ ALL ATTEMPTS FAILED for: \(address)")
                                            geocodingStatus = "Failed to geocode the address"
                                        }
                                    }
                                }
                            }
                        } else {
                            print("❌ FAILED and no numeric part found in: \(address)")
                            geocodingStatus = "Failed to geocode and no numeric part found"
                        }
                    }
                }
            }
        }
    }
    
    private func saveCoordinates() {
        do {
            try viewContext.save()
            print("💾 Saved geocoded coordinates to database: \(appointment.latitude), \(appointment.longitude)")
        } catch {
            print("❌ Error saving coordinates: \(error.localizedDescription)")
            geocodingStatus = "Error saving: \(error.localizedDescription)"
        }
    }
    
    private func testGeofence() {
        guard appointment.latitude != 0 && appointment.longitude != 0 else {
            geocodingStatus = "No coordinates to test"
            return
        }
        
        geocodingStatus = "Testing geofence..."
        
        // Use SceneDelegate's windows API for iOS 13+
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = window.rootViewController {
            
            print("✅ Found window and root view controller")
            
            // Try to find the ContentView by traversing the view controller hierarchy
            if let hostingController = rootVC as? UIHostingController<ContentView> {
                print("✅ Found ContentView hosting controller")
                
                let contentView = hostingController.rootView
                let safetyMonitorService = contentView.safetyMonitorService
                
                if let currentLocation = safetyMonitorService.currentLocation {
                    print("✅ Found current location from safety monitor service")
                    
                    let appointmentLocation = CLLocation(
                        latitude: appointment.latitude,
                        longitude: appointment.longitude
                    )
                    
                    let currentLocationObj = CLLocation(
                        latitude: currentLocation.latitude,
                        longitude: currentLocation.longitude
                    )
                    
                    let distance = currentLocationObj.distance(from: appointmentLocation)
                    let radius = 100.0 // Default geofence radius (100 meters)
                    
                    if distance <= radius {
                        geocodingStatus = "You are INSIDE the geofence! Distance: \(Int(distance))m"
                    } else {
                        geocodingStatus = "You are OUTSIDE the geofence. Distance: \(Int(distance))m, Radius: \(Int(radius))m"
                    }
                } else {
                    print("⚠️ No current location from safety monitor service")
                    geocodingStatus = "Cannot test: No current location available"
                }
            } else {
                print("⚠️ Could not find ContentView hosting controller")
                
                // Fall back to creating a temporary location manager
                let tempLocationManager = CLLocationManager()
                if let currentLocation = tempLocationManager.location {
                    print("✅ Using temporary location manager")
                    
                    let appointmentLocation = CLLocation(
                        latitude: appointment.latitude,
                        longitude: appointment.longitude
                    )
                    
                    let distance = currentLocation.distance(from: appointmentLocation)
                    geocodingStatus = "Distance to location: \(Int(distance))m"
                } else {
                    print("❌ No location available from temporary manager")
                    geocodingStatus = "Cannot access location services"
                }
            }
        } else {
            print("❌ Could not access window hierarchy")
            
            // Fall back to creating a temporary location manager as last resort
            let tempLocationManager = CLLocationManager()
            if let currentLocation = tempLocationManager.location {
                print("✅ Using temporary location manager (last resort)")
                
                let appointmentLocation = CLLocation(
                    latitude: appointment.latitude,
                    longitude: appointment.longitude
                )
                
                let distance = currentLocation.distance(from: appointmentLocation)
                geocodingStatus = "Distance to location: \(Int(distance))m"
            } else {
                print("❌ No location available from any source")
                geocodingStatus = "Cannot access location services from any source"
            }
        }
    }
    
    private func navigateToAppointment() {
        showingMapOptions = true
    }
    
    private func openInGoogleMaps() {
        guard appointment.latitude != 0 && appointment.longitude != 0 else { 
            print("❌ Cannot open Google Maps: Invalid coordinates (0,0)")
            geocodingStatus = "Error: Invalid coordinates for Google Maps"
            return 
        }
        
        let latitude = appointment.latitude
        let longitude = appointment.longitude
        let address = appointment.propertyAddress?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        print("🗺️ Attempting to open Google Maps with coordinates: \(latitude), \(longitude)")
        
        if !address.isEmpty {
            print("🗺️ Using address: \(address)")
            let urlString = "comgooglemaps://?daddr=\(address)&directionsmode=driving"
            print("🔗 URL: \(urlString)")
            
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    print("✅ Opening Google Maps app")
                    
                    // Use updated method to open URL
                    openURL(url) { success in
                        if success {
                            print("✅ Successfully opened Google Maps")
                        } else {
                            print("❌ Failed to open Google Maps app URL")
                            self.geocodingStatus = "Failed to open Google Maps"
                        }
                    }
                    return
                } else {
                    print("⚠️ Cannot open Google Maps app URL")
                }
            } else {
                print("⚠️ Invalid Google Maps app URL")
            }
            
            // Fallback to web URL with address
            let webUrlString = "https://maps.google.com/?daddr=\(address)"
            print("🔗 Web URL: \(webUrlString)")
            
            if let url = URL(string: webUrlString) {
                print("✅ Opening Google Maps in browser")
                
                // Use updated method to open URL
                openURL(url) { success in
                    if success {
                        print("✅ Successfully opened Google Maps in browser")
                    } else {
                        print("❌ Failed to open Google Maps in browser")
                        self.geocodingStatus = "Failed to open Google Maps in browser"
                    }
                }
                return
            } else {
                print("⚠️ Invalid Google Maps web URL")
            }
        }
        
        // Fallback to coordinates
        let appUrlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        print("🔗 Coordinate URL: \(appUrlString)")
        
        if let url = URL(string: appUrlString) {
            if UIApplication.shared.canOpenURL(url) {
                print("✅ Opening Google Maps app with coordinates")
                
                // Use updated method to open URL
                openURL(url) { success in
                    if success {
                        print("✅ Successfully opened Google Maps with coordinates")
                    } else {
                        print("❌ Failed to open Google Maps app with coordinates")
                        self.geocodingStatus = "Failed to open Google Maps with coordinates"
                    }
                }
                return
            } else {
                print("⚠️ Cannot open Google Maps app with coordinates")
            }
        } else {
            print("⚠️ Invalid Google Maps coordinate URL")
        }
        
        // Final fallback to web URL with coordinates
        let webCoordUrlString = "https://maps.google.com/?daddr=\(latitude),\(longitude)"
        print("🔗 Web coordinate URL: \(webCoordUrlString)")
        
        if let url = URL(string: webCoordUrlString) {
            print("✅ Opening Google Maps in browser with coordinates")
            
            // Use updated method to open URL
            openURL(url) { success in
                if success {
                    print("✅ Successfully opened Google Maps in browser with coordinates")
                } else {
                    print("❌ Failed to open Google Maps in browser with coordinates")
                    self.geocodingStatus = "Failed to open Google Maps in browser"
                }
            }
        } else {
            print("❌ All attempts to open Google Maps failed")
            geocodingStatus = "All attempts to open Google Maps failed"
        }
    }
    
    // Helper function to open URLs using iOS 15+ approach
    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        if #available(iOS 15.0, *) {
            // For iOS 15 and later
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        } else {
            // For iOS 14 and earlier
            let success = UIApplication.shared.open(url, options: [:], completionHandler: nil)
            completion(success)
        }
    }
    
    private func openInAppleMapsWithDirections() {
        guard appointment.latitude != 0 && appointment.longitude != 0 else {
            print("❌ Cannot open Apple Maps: Invalid coordinates (0,0)")
            geocodingStatus = "Error: Invalid coordinates for Apple Maps"
            return 
        }
        
        print("🗺️ Attempting to open Apple Maps with coordinates: \(appointment.latitude), \(appointment.longitude)")
        
        let coordinate = CLLocationCoordinate2DMake(appointment.latitude, appointment.longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        
        if let address = appointment.propertyAddress, !address.isEmpty {
            mapItem.name = address
            print("🗺️ Using address as name: \(address)")
        } else {
            mapItem.name = "Appointment Location"
            print("🗺️ Using default name: Appointment Location")
        }
        
        print("✅ Opening Apple Maps with directions")
        let success = mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
        
        if success {
            print("✅ Successfully launched Apple Maps")
        } else {
            print("❌ Failed to launch Apple Maps")
            geocodingStatus = "Failed to launch Apple Maps"
            
            // Fallback to URL scheme as a last resort
            if let url = URL(string: "maps://?daddr=\(appointment.latitude),\(appointment.longitude)&dirflg=d") {
                print("🔄 Trying fallback URL scheme for Apple Maps: \(url)")
                
                openURL(url) { success in
                    if success {
                        print("✅ Successfully opened Apple Maps via URL scheme")
                    } else {
                        print("❌ All attempts to open Apple Maps failed")
                        self.geocodingStatus = "All attempts to open Apple Maps failed"
                    }
                }
            }
        }
    }
    
    private func openInMaps() {
        guard appointment.latitude != 0 && appointment.longitude != 0 else {
            print("❌ Cannot open Maps: Invalid coordinates (0,0)")
            geocodingStatus = "Error: Invalid coordinates for Maps"
            return 
        }
        
        print("🗺️ Attempting to open Maps with coordinates: \(appointment.latitude), \(appointment.longitude)")
        
        let coordinate = CLLocationCoordinate2DMake(appointment.latitude, appointment.longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        
        if let address = appointment.propertyAddress, !address.isEmpty {
            mapItem.name = address
            print("🗺️ Using address as name: \(address)")
        } else {
            mapItem.name = "Appointment Location"
            print("🗺️ Using default name: Appointment Location")
        }
        
        print("✅ Opening Maps without directions")
        // Just show the location without directions
        let success = mapItem.openInMaps(launchOptions: nil)
        
        if success {
            print("✅ Successfully launched Maps")
        } else {
            print("❌ Failed to launch Maps")
            geocodingStatus = "Failed to launch Maps"
            
            // Fallback to URL scheme as a last resort
            if let url = URL(string: "maps://?ll=\(appointment.latitude),\(appointment.longitude)") {
                print("🔄 Trying fallback URL scheme for Maps: \(url)")
                
                openURL(url) { success in
                    if success {
                        print("✅ Successfully opened Maps via URL scheme")
                    } else {
                        print("❌ All attempts to open Maps failed")
                        self.geocodingStatus = "All attempts to open Maps failed"
                    }
                }
            }
        }
    }
    
    private func callPhone(_ number: String) {
        let cleanedNumber = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard let url = URL(string: "tel://\(cleanedNumber)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func sendEmail(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let appointment = AppointmentEntity(context: context)
    appointment.title = "123 Main St Showing"
    appointment.propertyAddress = "123 Main St"
    appointment.startTime = Date()
    appointment.endTime = Date().addingTimeInterval(3600)
    appointment.latitude = 32.7767
    appointment.longitude = -96.7970
    
    return AppointmentDetailCoreDataView(appointment: appointment)
        .environment(\.managedObjectContext, context)
} 