#if compiler(>=5.3)
// Increase type-checker compile time limit for complex views
#elseif compiler(>=5.0)
// Use directive specific to Swift 5.0+
#endif

import SwiftUI
import MapKit
import CoreData
import CoreLocation
import Foundation
import FirebaseFirestore // Required for Firestore integrations
import FirebaseAuth // Required for Firebase Authentication

// Define our own MapAnnotationItem struct to avoid import issues
struct DetailMapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// Location manager delegate to handle location updates
class AppointmentLocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location.coordinate
            if let onLocationUpdate = onLocationUpdate {
                onLocationUpdate(location.coordinate)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// Define a temporary local version to resolve the compilation error
// TODO: This is a temporary workaround to fix the "Cannot find ShowingCompleteView in scope" error
// In a future update, we should fix the module structure to properly expose ShowingCompleteView
struct LocalShowingCompleteView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    var appointment: AppointmentEntity
    
    @State private var clientFeedback: String = ""
    @State private var rating: Int = 5
    @State private var feltSafe: Bool = true
    @State private var safetyNotes: String = ""
    @State private var generalNotes: String = ""
    @State private var followUpNeeded: Bool = false
    @State private var followUpNotes: String = ""
    @State private var clientAttended: Bool = true
    @State private var completionTime: Date = Date()
    @State private var isSaving: Bool = false
    @State private var showingConfirmation: Bool = false
    @State private var showingGeocodeAlert: Bool = false
    @State private var geocodeMessage: String = ""
    @State private var showSafetyNotes: Bool = false
    @State private var animatedStar: Int? = nil
    
    // Haptic feedback generator
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with property info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appointment.title ?? "Untitled Appointment")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(appointment.propertyAddress ?? "No address")
                            .font(.subheadline)
                        
                        Text("Completed on \(formattedDate(completionTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Client attendance
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $clientAttended) {
                            HStack {
                                Image(systemName: clientAttended ? "person.fill.checkmark" : "person.fill.xmark")
                                    .foregroundColor(clientAttended ? .green : .orange)
                                Text("Client attended the showing").font(.headline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Client feedback (only if attended)
                    if clientAttended {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Client Feedback")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            TextEditor(text: $clientFeedback)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                            
                            // Interest rating
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Client Interest Level")
                                    .font(.headline)
                                
                                HStack {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundColor(star <= rating ? .yellow : .gray)
                                            .font(.title2)
                                            .scaleEffect(animatedStar == star ? 1.4 : 1.0)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animatedStar)
                                            .onTapGesture {
                                                feedbackGenerator.impactOccurred()
                                                rating = star
                                                withAnimation {
                                                    animatedStar = star
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    withAnimation {
                                                        animatedStar = nil
                                                    }
                                                }
                                            }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(ratingDescription(rating))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Safety section
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $feltSafe) {
                            HStack {
                                Image(systemName: "shield.fill").foregroundColor(feltSafe ? .green : .red)
                                Text("Did you feel safe during the showing?").font(.headline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        if !feltSafe {
                            Text("Please provide details about your safety concerns:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            
                            TextEditor(text: $safetyNotes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.5), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Notes about showing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes About Showing")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        TextEditor(text: $generalNotes)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    }
                    .padding(.horizontal)
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            saveShowingCompletion()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Save & Exit").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)
                        
                        Button(action: {
                            saveShowingCompletion(andSendRecap: true)
                        }) {
                            HStack {
                                Image(systemName: "envelope")
                                Text("Send Recap to Office").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSaving)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Completed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showingGeocodeAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(geocodeMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // Helper function for formatted date
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function for rating description
    private func ratingDescription(_ rating: Int) -> String {
        switch rating {
        case 1: return "Not interested"
        case 2: return "Slightly interested"
        case 3: return "Moderately interested"
        case 4: return "Very interested"
        case 5: return "Extremely interested"
        default: return ""
        }
    }
    
    // Save the showing completion to Firebase
    private func saveShowingCompletion(andSendRecap: Bool = false) {
        isSaving = true
        
        // More detailed debugging of the appointment entity
        print("Debug - Appointment details:")
        print("Debug - ID: \(appointment.id ?? "nil")")
        print("Debug - Title: \(appointment.title ?? "nil")")
        print("Debug - Property Address: \(appointment.propertyAddress ?? "nil")")
        print("Debug - Coordinates: (\(appointment.latitude), \(appointment.longitude))")
        
        // Don't require a valid UUID format - use the ID string directly
        guard let idString = appointment.id, !idString.isEmpty else {
            print("Error: Empty or nil appointment ID")
            feedbackGenerator.impactOccurred(intensity: 1.0)
            isSaving = false
            self.geocodeMessage = "Error: Unable to save - No appointment ID"
            self.showingGeocodeAlert = true
            return
        }
        
        // Generate a unique ID for Firestore
        let uniqueDocId = UUID().uuidString
        print("Debug - Using generated unique ID for Firestore: \(uniqueDocId)")
        
        // Debug the data being sent
        print("Debug - Saving appointment to Firestore - Address: \(appointment.propertyAddress ?? "Unknown")")
        print("Debug - Coordinates: \(appointment.latitude), \(appointment.longitude)")
        
        // Save to user-specific Firestore collection
        saveShowingCompletionInUserCollection(
            appointmentId: idString,
            propertyAddress: appointment.propertyAddress ?? "Unknown Address",
            completionTime: completionTime,
            clientAttended: clientAttended,
            feltSafe: feltSafe,
            safetyNotes: feltSafe ? nil : safetyNotes,
            clientFeedback: clientAttended ? clientFeedback : nil,
            interestRating: clientAttended ? rating : nil,
            followUpNeeded: followUpNeeded,
            followUpNotes: followUpNeeded ? followUpNotes : nil,
            generalNotes: generalNotes.isEmpty ? nil : generalNotes,
            latitude: appointment.latitude,
            longitude: appointment.longitude,
            documentId: uniqueDocId,
            sendToOffice: andSendRecap
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success(let docId):
                    if andSendRecap {
                        print("Successfully sent showing recap to office with ID: \(docId)")
                    } else {
                        print("Successfully saved showing completion to Firestore with ID: \(docId)")
                    }
                    
                    // Also update local Core Data model
                    self.appointment.status = "completed"
                    
                    do {
                        try self.viewContext.save()
                        print("Core Data status updated to completed")
                    } catch {
                        print("Error updating Core Data: \(error.localizedDescription)")
                    }
                    
                    // Provide haptic feedback for successful save
                    self.feedbackGenerator.impactOccurred(intensity: 0.5)
                    
                    // Show confirmation briefly before dismissing
                    self.showingConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                    
                case .failure(let error):
                    print("Error saving to Firestore: \(error.localizedDescription)")
                    self.feedbackGenerator.impactOccurred(intensity: 1.0)
                    
                    // Show error alert
                    self.geocodeMessage = "Error saving: \(error.localizedDescription)"
                    self.showingGeocodeAlert = true
                }
            }
        }
    }
    
    // A modified version that writes to a user-specific subcollection
    private func saveShowingCompletionInUserCollection(
        appointmentId: String,
        propertyAddress: String,
        completionTime: Date,
        clientAttended: Bool,
        feltSafe: Bool,
        safetyNotes: String?,
        clientFeedback: String?,
        interestRating: Int?,
        followUpNeeded: Bool,
        followUpNotes: String?,
        generalNotes: String?,
        latitude: Double,
        longitude: Double,
        documentId: String?,
        sendToOffice: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Get Firestore instance
        let db = Firestore.firestore()
        
        // Get the current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        print("Debug - Using user ID: \(currentUserId)")
        
        // FIXING COLLECTION PATH ISSUES:
        // Use the collection paths that match the security rules
        let showingCompletionRef: DocumentReference
        
        if sendToOffice {
            // Use officeRecaps collection as specified in the security rules
            if let docId = documentId {
                showingCompletionRef = db.collection("officeRecaps").document(docId)
            } else {
                showingCompletionRef = db.collection("officeRecaps").document()
            }
            print("Debug - Using officeRecaps collection with document ID: \(showingCompletionRef.documentID)")
        } else {
            // Use showingCompletions collection as specified in the security rules
            if let docId = documentId {
                showingCompletionRef = db.collection("showingCompletions").document(docId)
            } else {
                showingCompletionRef = db.collection("showingCompletions").document()
            }
            print("Debug - Using showingCompletions collection with document ID: \(showingCompletionRef.documentID)")
        }
        
        let showingId = showingCompletionRef.documentID
        
        // Get user details for the recap
        let userRef = db.collection("users").document(currentUserId)
        userRef.getDocument { (userDoc, userError) in
            // Extract user data if available
            let userData = userDoc?.data() ?? [:]
            let agentName = userData["name"] as? String ?? "Unknown Agent"
            let agentEmail = userData["email"] as? String ?? "Unknown Email"
            let agentPhone = userData["phone"] as? String ?? "Unknown Phone"
            
            // Prepare the data to save
            var data: [String: Any] = [
                "showingId": showingId,
                "appointmentId": appointmentId,
                "agentId": currentUserId,
                "agentName": agentName,
                "agentEmail": agentEmail,
                "agentPhone": agentPhone,
                "propertyAddress": propertyAddress,
                "completionTime": completionTime,
                "clientAttended": clientAttended,
                "feltSafe": feltSafe,
                "followUpNeeded": followUpNeeded,
                "latitude": latitude,
                "longitude": longitude,
                "status": "completed",
                "sentToOffice": sendToOffice,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            // Add optional fields if they have values
            if let safetyNotes = safetyNotes, !safetyNotes.isEmpty {
                data["safetyNotes"] = safetyNotes
            }
            
            if clientAttended {
                if let clientFeedback = clientFeedback, !clientFeedback.isEmpty {
                    data["clientFeedback"] = clientFeedback
                }
                
                if let interestRating = interestRating {
                    data["interestRating"] = interestRating
                }
            }
            
            if followUpNeeded, let followUpNotes = followUpNotes, !followUpNotes.isEmpty {
                data["followUpNotes"] = followUpNotes
            }
            
            if let generalNotes = generalNotes, !generalNotes.isEmpty {
                data["generalNotes"] = generalNotes
            }
            
            print("Debug - Saving document with data: \(data)")
            
            // Save the data to Firestore
            showingCompletionRef.setData(data) { error in
                if let error = error {
                    print("Error saving showing completion: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("Successfully saved showing data with ID: \(showingId)")
                    
                    // Also update the appointment status in the user's subcollection
                    let appointmentRef = db.collection("users")
                        .document(currentUserId)
                        .collection("appointments")
                        .document(appointmentId)
                    
                    var statusData: [String: Any] = [
                        "status": "completed",
                        "updatedAt": FieldValue.serverTimestamp(),
                        "completionId": showingId
                    ]
                    
                    statusData["completionTime"] = completionTime
                    statusData["sentToOffice"] = sendToOffice
                    
                    // Use setData with merge:true to handle non-existent documents
                    appointmentRef.setData(statusData, merge: true) { error in
                        if let error = error {
                            print("Warning: Status update failed: \(error.localizedDescription)")
                            // Still return success since we saved the main document
                        } else {
                            print("Successfully updated appointment status to completed")
                        }
                        
                        // Also save a record in the user's sent recaps collection if sending to office
                        if sendToOffice {
                            print("Successfully sent showing recap to office with ID: \(showingId)")
                            
                            // Create a record in the user's collection to track this recap
                            let sentRecapRef = db.collection("users")
                                .document(currentUserId)
                                .collection("sentRecaps")
                                .document(showingId)
                            
                            let sentRecapData: [String: Any] = [
                                "showingId": showingId,
                                "appointmentId": appointmentId,
                                "propertyAddress": propertyAddress,
                                "sentAt": FieldValue.serverTimestamp(),
                                "status": "sent"
                            ]
                            
                            sentRecapRef.setData(sentRecapData) { finalError in
                                if let finalError = finalError {
                                    print("Warning: Failed to record sent recap: \(finalError.localizedDescription)")
                                } else {
                                    print("Successfully recorded sent recap in user's collection")
                                }
                                
                                // Try to also update the agent info in the user document if it's missing/unknown
                                if agentName == "Unknown Agent" || agentEmail == "Unknown Email" || agentPhone == "Unknown Phone" {
                                    self.updateUserProfile(userId: currentUserId)
                                }
                                
                                completion(.success(showingId))
                            }
                        } else {
                            // Try to also update the agent info in the user document if it's missing/unknown
                            if agentName == "Unknown Agent" || agentEmail == "Unknown Email" || agentPhone == "Unknown Phone" {
                                self.updateUserProfile(userId: currentUserId)
                            }
                            
                            completion(.success(showingId))
                        }
                    }
                }
            }
        }
    }
    
    // Helper method to update the user profile with default information if missing
    private func updateUserProfile(userId: String) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        // Get the current user from Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            return
        }
        
        // Build the update data from the authenticated user info
        var updateData: [String: Any] = [:]
        
        if let email = currentUser.email {
            updateData["email"] = email
        }
        
        if let displayName = currentUser.displayName {
            updateData["name"] = displayName
        }
        
        if let phoneNumber = currentUser.phoneNumber {
            updateData["phone"] = phoneNumber
        }
        
        // Only update if we have some data
        if !updateData.isEmpty {
            userRef.setData(updateData, merge: true) { error in
                if let error = error {
                    print("Warning: Failed to update user profile: \(error.localizedDescription)")
                } else {
                    print("Successfully updated user profile information")
                }
            }
        }
    }
}

struct AppointmentDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    let appointmentID: String

    @FetchRequest(
        entity: AppointmentEntity.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "id == %@", argumentArray: ["" /* will be set in init */]),
        animation: .default
    ) private var appointments: FetchedResults<AppointmentEntity>

    @State private var isRefreshing = false
    @State private var showingGeocodeAlert = false
    @State private var geocodeMessage = ""
    @State private var mapRegion = MKCoordinateRegion()
    @State private var hasSetInitialRegion = false
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var distanceToAppointment: Double?
    @State private var isTrackingUser = false
    @State private var showingCompleteView = false
    @StateObject private var locationDelegate = AppointmentLocationDelegate()
    private let locationManager = CLLocationManager()

    init(appointmentID: String) {
        self.appointmentID = appointmentID
        // Set the predicate for the fetch request
        let predicate = NSPredicate(format: "id == %@", appointmentID)
        _appointments = FetchRequest(
            entity: AppointmentEntity.entity(),
            sortDescriptors: [],
            predicate: predicate,
            animation: .default
        )
    }

    // MARK: - Private Helper Methods
    
    // Get color based on appointment status
    private func getStatusColor(_ appointment: AppointmentEntity) -> Color {
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
    
    // Geocode address function with improved accuracy
    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        // Clean up the address for better geocoding results
        let cleanAddress = cleanupAddressForGeocoding(address)
        
        print("🔍 GEOCODING: '\(cleanAddress)' (original: '\(address)')")
        
        // Use Apple's standard geocoder with improved options
        let geocoder = CLGeocoder()
        
        // Move geocoding to background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Create a timeout to prevent indefinite waiting
            var hasCompleted = false
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 10) {
                if !hasCompleted {
                    print("⏰ Geocoding timed out for: \(address)")
                    hasCompleted = true
                    completion(nil)
                }
            }
            
            // Try with complete address information including city, state and zip
            let fullAddress = ensureAddressHasRegion(cleanAddress)
            
            // Use proper geocoding with complete address information
            geocoder.geocodeAddressString(fullAddress) { placemarks, error in
                if hasCompleted { return } // Already timed out
                
                if let error = error {
                    print("❌ Geocoding error: \(error.localizedDescription)")
                    
                    // Try with more specific address format
                    let addressWithZip = "\(cleanAddress), Anna, TX 75409"
                    print("🔄 Retrying with specific format: '\(addressWithZip)'")
                    
                    geocoder.geocodeAddressString(addressWithZip) { placemarks, error in
                        if hasCompleted { return }
                        hasCompleted = true
                        
                        if let error = error {
                            print("❌ Specific format geocoding error: \(error.localizedDescription)")
                            completion(nil)
                            return
                        }
                        
                        self.processPlacemarks(placemarks, for: addressWithZip, completion: completion)
                    }
                    return
                }
                
                hasCompleted = true
                self.processPlacemarks(placemarks, for: fullAddress, completion: completion)
            }
        }
    }
    
    // Helper to process placemarks consistently
    private func processPlacemarks(_ placemarks: [CLPlacemark]?, for address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        guard let placemarks = placemarks, !placemarks.isEmpty else {
            print("❌ No placemarks found for address: \(address)")
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
            print("✅ Successfully geocoded '\(address)' to: \(coordinate.latitude), \(coordinate.longitude)")
            
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
            print("❌ Placemark found but no coordinates for address: \(address)")
            completion(nil)
        }
    }
    
    // Helper to extract numeric address
    private func extractNumericAddress(from address: String) -> String? {
        // Match patterns like "123 Main St" or "456 Elm Avenue"
        let pattern = "\\d+\\s+[A-Za-z]+"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = address as NSString
            let matches = regex.matches(in: address, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = matches.first {
                return nsString.substring(with: match.range)
            }
        }
        
        return nil
    }
    
    // Helper to ensure address has city and state
    private func ensureAddressHasRegion(_ address: String) -> String {
        // Check if address already contains city or state information
        let lowercaseAddress = address.lowercased()
        
        // If address already has zip code, it's likely complete
        if lowercaseAddress.contains("75409") {
            return address
        }
        
        // If it has both city and state, just make sure format is correct
        if lowercaseAddress.contains("anna") && lowercaseAddress.contains("tx") {
            // Check if it has proper formatting
            if !lowercaseAddress.contains(", anna") && !lowercaseAddress.contains("anna,") {
                // Fix formatting
                let cleanedAddress = address.replacingOccurrences(of: "anna", with: ", Anna", options: [.caseInsensitive], range: nil)
                    .replacingOccurrences(of: "  ", with: " ")
                
                // Add zip code if missing
                if !lowercaseAddress.contains("75409") {
                    return "\(cleanedAddress), 75409"
                }
                
                return cleanedAddress
            }
            
            // Add zip code if missing
            if !lowercaseAddress.contains("75409") {
                return "\(address), 75409"
            }
            
            return address // Already has city and state
        }
        
        if lowercaseAddress.contains("anna") {
            return "\(address), TX 75409" // Add state and zip
        }
        
        if lowercaseAddress.contains("tx") {
            return "\(address), Anna, 75409" // Add city and zip
        }
        
        // Add complete address information
        return "\(address), Anna, TX 75409"
    }
    
    // Helper to clean up address for better geocoding
    private func cleanupAddressForGeocoding(_ address: String) -> String {
        // Remove any characters that might interfere with geocoding
        var cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any text in parentheses which often contains non-address information
        if let rangeStart = cleanAddress.range(of: "("),
           let rangeEnd = cleanAddress.range(of: ")", options: [], range: rangeStart.upperBound..<cleanAddress.endIndex) {
            let fullRange = rangeStart.lowerBound..<rangeEnd.upperBound
            cleanAddress.removeSubrange(fullRange)
        }
        
        // Remove common prefixes that aren't part of the actual address
        let prefixesToRemove = ["property:", "address:", "location:", "showing:"]
        for prefix in prefixesToRemove {
            if cleanAddress.lowercased().hasPrefix(prefix) {
                cleanAddress = String(cleanAddress.dropFirst(prefix.count))
            }
        }
        
        // Standardize address format
        cleanAddress = cleanAddress.replacingOccurrences(of: ",", with: ", ")
        cleanAddress = cleanAddress.replacingOccurrences(of: "  ", with: " ")
        
        // Make sure street name is properly formatted
        if cleanAddress.lowercased().contains("portina") && !cleanAddress.lowercased().contains("portina dr") {
            cleanAddress = cleanAddress.replacingOccurrences(of: "portina", with: "Portina Dr", options: [.caseInsensitive], range: nil)
        }
        
        return cleanAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Helper to calculate distance between coordinates in meters
    private func calculateDistance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }

    var body: some View {
        if let appointment = appointments.first {
            AppointmentDetailContent(
                appointment: appointment,
                mapRegion: $mapRegion,
                hasSetInitialRegion: $hasSetInitialRegion,
                userLocation: $userLocation,
                distanceToAppointment: $distanceToAppointment,
                isTrackingUser: $isTrackingUser,
                isRefreshing: $isRefreshing,
                showingGeocodeAlert: $showingGeocodeAlert,
                geocodeMessage: $geocodeMessage,
                showingCompleteView: $showingCompleteView,
                getStatusColor: getStatusColor,
                geocodeAddress: geocodeAddress,
                calculateDistance: calculateDistance,
                regionThatFitsBothLocations: regionThatFitsBothLocations,
                presentationMode: presentationMode,
                viewContext: viewContext
            )
            .onAppear {
                // Make sure the appointment has a valid ID to avoid issues with ShowingCompleteView
                if appointment.id == nil || appointment.id?.isEmpty == true {
                    appointment.id = UUID().uuidString
                    do {
                        try viewContext.save()
                        print("Generated and saved new ID for appointment: \(appointment.id ?? "unknown")")
                    } catch {
                        print("Failed to save new appointment ID: \(error)")
                    }
                }
                // Initialize a default map region if needed
                if !hasSetInitialRegion && appointment.latitude != 0 && appointment.longitude != 0 {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: appointment.latitude,
                        longitude: appointment.longitude
                    )
                    mapRegion = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    hasSetInitialRegion = true
                }
                // Force geocoding for debug
                if let address = appointment.propertyAddress, !address.isEmpty {
                    print("🟡 [FORCE] Geocoding will start for address: \(address)")
                    geocodeAddress(address) { coordinate in
                        if let coordinate = coordinate {
                            appointment.latitude = coordinate.latitude
                            appointment.longitude = coordinate.longitude
                            do {
                                try viewContext.save()
                                print("✅ Saved geocoded coordinates: \(coordinate.latitude), \(coordinate.longitude)")
                            } catch {
                                print("❌ Failed to save geocoded coordinates: \(error)")
                            }
                            // Update map region after geocoding
                            mapRegion = MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                            hasSetInitialRegion = true
                            print("🗺️ Map region updated after geocoding.")
                        } else {
                            print("❌ Geocoding failed for address: \(address)")
                        }
                    }
                }
            }
        } else {
            Text("Appointment not found.")
        }
    }
    
    // Extracted content view to improve compiler performance
    private struct AppointmentDetailContent: View {
        let appointment: AppointmentEntity
        @Binding var mapRegion: MKCoordinateRegion
        @Binding var hasSetInitialRegion: Bool
        @Binding var userLocation: CLLocationCoordinate2D?
        @Binding var distanceToAppointment: Double?
        @Binding var isTrackingUser: Bool
        @Binding var isRefreshing: Bool
        @Binding var showingGeocodeAlert: Bool
        @Binding var geocodeMessage: String
        @Binding var showingCompleteView: Bool
        
        let getStatusColor: (AppointmentEntity) -> Color
        let geocodeAddress: (String, @escaping (CLLocationCoordinate2D?) -> Void) -> Void
        let calculateDistance: (CLLocationCoordinate2D, CLLocationCoordinate2D) -> Double
        let regionThatFitsBothLocations: (CLLocationCoordinate2D, CLLocationCoordinate2D) -> MKCoordinateRegion
        let presentationMode: Binding<PresentationMode>
        let viewContext: NSManagedObjectContext
        
        var body: some View {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Content Sections
                    VStack(spacing: 16) {
                        // Appointment Time Section
                        appointmentTimeSection
                        
                        // Property Details Section
                        propertyDetailsSection
                        
                        // Actions Section
                        actionsSection
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitle("Showing Details", displayMode: .inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    refreshButton
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    dismissButton
                }
            }
            .alert(isPresented: $showingGeocodeAlert) {
                Alert(
                    title: Text("Location Update"),
                    message: Text(geocodeMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        
        // Header Section
        private var headerSection: some View {
            ZStack(alignment: .top) {
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
                    .frame(height: 200)
                    .edgesIgnoringSafeArea(.top)
                
                // Status pill - positioned at the top
                HStack {
                    Text(appointment.status?.capitalized ?? "Scheduled")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(getStatusColor(appointment).opacity(0.2))
                        .foregroundColor(getStatusColor(appointment))
                        .cornerRadius(20)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 50) // Adjust this value to position the pill correctly
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
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
                    
                    // Time remaining indicator
                    timeRemainingView
                }
                .padding(.horizontal)
                .padding(.top, 90) // Adjust this value to position the content below the pill
                .padding(.bottom, 20)
            }
        }
        
        // Time Remaining View
        private var timeRemainingView: some View {
            Group {
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
        }
        
        // Appointment Time Section
        private var appointmentTimeSection: some View {
            customSectionView(title: "Appointment Time") {
                if let start = appointment.startTime, let end = appointment.endTime {
                    VStack(spacing: 8) {
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
        }
        
        // Property Details Section
        private var propertyDetailsSection: some View {
            customSectionView(title: "Property Details") {
                // MLS Number
                customDetailRow(icon: "number", iconColor: .blue, title: "MLS #", value: "Not available")
                
                // For price, show a placeholder
                customDetailRow(icon: "dollarsign.circle", iconColor: .green, title: "Listing Price", value: "Contact agent")
                
                // Property details placeholder
                customDetailRow(icon: "house", iconColor: .blue, title: "Details", value: "Property details coming soon")
                
                Divider()
                    .padding(.vertical, 8)
                
                // Location section
                locationSection
            }
        }
        
        // Location Section
        private var locationSection: some View {
            VStack(alignment: .leading) {
                Text("Location")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                if let address = appointment.propertyAddress, !address.isEmpty {
                    // Always show location section for any appointment with an address
                    Text(address)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 8)
                    
                    // Create coordinate if available, otherwise nil
                    let coordinate: CLLocationCoordinate2D? = (appointment.latitude != 0 && appointment.longitude != 0) 
                        ? CLLocationCoordinate2D(latitude: appointment.latitude, longitude: appointment.longitude)
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
                    
                    // Show map when coordinates are available
                    if let coordinate = coordinate {
                        mapView(coordinate: coordinate)
                    } else {
                        // Show a placeholder when coordinates are not yet available
                        VStack {
                            Text("Map will appear after coordinates are loaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(height: 100)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.bottom, 12)
                    }
                    
                    // Map actions
                    mapActionsView(coordinate: coordinate)
                } else {
                    Text("No address information available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        // Map View
        private func mapView(coordinate: CLLocationCoordinate2D) -> some View {
            VStack(spacing: 8) {
                // Distance indicator
                if let distance = distanceToAppointment {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.blue)
                        let distanceInFeet = distance * 3.28084
                        if distance < 100 {
                            Text("You are at this location")
                                .font(.callout)
                                .foregroundColor(.green)
                        } else if distance < 1000 {
                            Text("You are \(Int(distanceInFeet)) feet away")
                                .font(.callout)
                                .foregroundColor(.blue)
                        } else {
                            let distanceInMiles = distanceInFeet / 5280
                            Text("You are \(String(format: "%.1f", distanceInMiles)) miles away")
                                .font(.callout)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                let localRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
                let binding = Binding<MKCoordinateRegion>(
                    get: { localRegion },
                    set: { _ in }
                )
                ZStack {
                    Map(coordinateRegion: binding, 
                        interactionModes: [],
                        annotationItems: [DetailMapAnnotationItem(coordinate: coordinate)]) { item in
                        MapAnnotation(coordinate: item.coordinate) {
                            VStack {
                                Image(systemName: "house.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                                Text(appointment.propertyAddress?.components(separatedBy: ",").first ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.black)
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
            }
            .padding(.bottom, 12)
        }
        
        // Map Actions View
        private func mapActionsView(coordinate: CLLocationCoordinate2D?) -> some View {
            HStack(spacing: 12) {
                if let coordinate = coordinate {
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: {
                            // Open in maps with improved options
                            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                            mapItem.name = appointment.propertyAddress
                            
                            // Use more options for better navigation
                            let options: [String: Any] = [
                                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
                                MKLaunchOptionsShowsTrafficKey: true
                            ]
                            
                            mapItem.openInMaps(launchOptions: options)
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Directions")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // Note about Apple Maps directions
                        Text("Note: Apple Maps may show driving time rather than direct distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Map navigation will be available after coordinates are loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        
        // Actions Section
        private var actionsSection: some View {
            customSectionView(title: "Actions") {
                Button(action: {
                    // Debug print statement for tracking
                    print("Debug: Mark Complete button tapped")
                    
                    // Ensure appointment has a valid ID before presenting ShowingCompleteView
                    if appointment.id == nil || appointment.id?.isEmpty == true {
                        appointment.id = UUID().uuidString
                        
                        // Try to save the context immediately
                        do {
                            try viewContext.save()
                            print("Debug: Generated and saved new ID: \(appointment.id ?? "unknown")")
                        } catch {
                            print("Debug: Error saving new ID: \(error)")
                        }
                    }
                    
                    // Use DispatchQueue.main.async to ensure UI updates properly
                    DispatchQueue.main.async {
                        // Show the ShowingCompleteView
                        self.showingCompleteView = true
                        print("Debug: Set showingCompleteView to true")
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Mark Complete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(BorderlessButtonStyle()) // Add this to fix potential tap issues
                .padding(.bottom, 8)
                .fullScreenCover(isPresented: $showingCompleteView) {
                    LocalShowingCompleteView(appointment: appointment)
                        .environment(\.managedObjectContext, viewContext)
                }
                
                Button(action: {
                    // Emergency action
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.shield")
                        Text("Emergency Alert")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        
        // Refresh Button
        private var refreshButton: some View {
            Button(action: {
                isRefreshing = true
                
                // Trigger geocoding
                if let address = appointment.propertyAddress, !address.isEmpty {
                    geocodeAddress(address) { newCoordinate in
                        DispatchQueue.main.async {
                            isRefreshing = false
                            
                            if let newCoordinate = newCoordinate {
                                print("✅ Successfully refreshed coordinates: \(newCoordinate.latitude), \(newCoordinate.longitude)")
                                
                                if let idString = appointment.id, let id = UUID(uuidString: idString) {
                                    AppointmentService.shared.updateAppointmentCoordinates(
                                        appointmentId: id,
                                        latitude: newCoordinate.latitude,
                                        longitude: newCoordinate.longitude
                                    )
                                    
                                    // Show success message
                                    geocodeMessage = "Updated coordinates successfully!"
                                    showingGeocodeAlert = true
                                } else {
                                    // Invalid ID
                                    geocodeMessage = "Could not update coordinates - invalid appointment ID"
                                    showingGeocodeAlert = true
                                }
                            } else {
                                geocodeMessage = "Unable to update coordinates"
                                showingGeocodeAlert = true
                            }
                        }
                    }
                } else {
                    isRefreshing = false
                    geocodeMessage = "No address to geocode"
                    showingGeocodeAlert = true
                }
            }) {
                if isRefreshing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
        }
        
        // Dismiss Button
        private var dismissButton: some View {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.primary)
            }
        }
        
        // Helper function for custom section views
        private func customSectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
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
        
        // Helper function for custom detail rows
        private func customDetailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
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
    }
    
    // MARK: - Helper Methods
    
    // Helper method to calculate a region that fits both locations
    private func regionThatFitsBothLocations(userLocation: CLLocationCoordinate2D, appointmentLocation: CLLocationCoordinate2D) -> MKCoordinateRegion {
        // Calculate the center point between the two locations
        let centerLatitude = (userLocation.latitude + appointmentLocation.latitude) / 2
        let centerLongitude = (userLocation.longitude + appointmentLocation.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        
        // Calculate the span needed to show both points with padding
        let latDelta = abs(userLocation.latitude - appointmentLocation.latitude) * 1.5
        let lonDelta = abs(userLocation.longitude - appointmentLocation.longitude) * 1.5
        
        // Ensure minimum zoom level for visibility
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, latDelta),
            longitudeDelta: max(0.005, lonDelta)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    // Helper method to ensure appointment has a valid ID
    private func ensureValidAppointmentId(_ appointment: AppointmentEntity) -> AppointmentEntity {
        // Ensure appointment has a valid ID
        if appointment.id == nil {
            // Generate a new UUID for the appointment
            appointment.id = UUID().uuidString
        }
        return appointment
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let appointment = AppointmentEntity(context: context)
    appointment.id = UUID().uuidString
    appointment.title = "123 Main St Showing"
    appointment.propertyAddress = "123 Main St, Anna, TX"
    appointment.startTime = Date()
    appointment.endTime = Date().addingTimeInterval(3600)
    appointment.latitude = 33.350788
    appointment.longitude = -96.526566
    appointment.status = "scheduled"
    
    return AppointmentDetailView(appointmentID: appointment.id ?? "")
        .environment(\.managedObjectContext, context)
}
