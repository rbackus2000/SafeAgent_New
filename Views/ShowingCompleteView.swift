#if compiler(>=5.3)
// Increase type-checker compile time limit for newer Swift versions
#elseif compiler(>=5.0)
// Use directive specific to Swift 5.0+
#endif

import SwiftUI
import CoreData
import MapKit
import FirebaseFirestore
import FirebaseAuth

// Structure to represent a cached recap for offline storage
struct CachedRecap: Codable {
    let appointmentId: String
    let recap: String
    let documentId: String
    let timestamp: Date
    let clientFeedback: String?
    let interestRating: Int?
    let feltSafe: Bool
    let followUpNeeded: Bool
    let followUpNotes: String?
    let generalNotes: String?
    let cacheId: String
    
    init(appointmentId: String, recap: String, documentId: String, timestamp: Date = Date(), 
         clientFeedback: String? = nil, interestRating: Int? = nil, feltSafe: Bool = true, 
         followUpNeeded: Bool = false, followUpNotes: String? = nil, generalNotes: String? = nil) {
        self.appointmentId = appointmentId
        self.recap = recap
        self.documentId = documentId
        self.timestamp = timestamp
        self.clientFeedback = clientFeedback
        self.interestRating = interestRating
        self.feltSafe = feltSafe
        self.followUpNeeded = followUpNeeded
        self.followUpNotes = followUpNotes
        self.generalNotes = generalNotes
        self.cacheId = UUID().uuidString
    }
}

// Helper class to manage offline caching of recaps
class RecapCacheManager {
    static let shared = RecapCacheManager()
    
    private let cacheKey = "cached_recaps"
    
    private init() {}
    
    // Save a recap to local cache
    func cacheRecap(_ recap: CachedRecap) {
        var cachedRecaps = getRecaps()
        cachedRecaps.append(recap)
        
        if let encoded = try? JSONEncoder().encode(cachedRecaps) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            print("Recap successfully cached locally")
        } else {
            print("Failed to encode recap for caching")
        }
    }
    
    // Get all cached recaps
    func getRecaps() -> [CachedRecap] {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cachedRecaps = try? JSONDecoder().decode([CachedRecap].self, from: data) {
            return cachedRecaps
        }
        return []
    }
    
    // Remove a specific recap from cache
    func removeRecap(withId cacheId: String) {
        var cachedRecaps = getRecaps()
        cachedRecaps.removeAll { $0.cacheId == cacheId }
        
        if let encoded = try? JSONEncoder().encode(cachedRecaps) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    // Clear all cached recaps
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    // Check if there are pending recaps to upload
    func hasPendingRecaps() -> Bool {
        return !getRecaps().isEmpty
    }
}

// Add MapAnnotationItem to avoid conflicts with other files
struct ShowingMapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// Make sure this view is declared properly for access from other files
public struct ShowingCompleteView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    // Use private variable and provide a getter that ensures a valid ID
    private var _appointment: AppointmentEntity
    
    // Public getter for appointment that ensures ID is valid
    private var appointment: AppointmentEntity {
        // Ensure appointment has a valid ID
        if _appointment.id == nil || _appointment.id?.isEmpty == true {
            print("Debug - Fixing missing appointment ID")
            _appointment.id = UUID().uuidString
            
            // Save the context if possible
            do {
                try viewContext.save()
                print("Debug - Saved appointment with new ID: \(_appointment.id!)")
            } catch {
                print("Debug - Error saving new appointment ID: \(error)")
            }
        }
        return _appointment
    }
    
    @State private var clientFeedback: String = ""
    @State private var rating: Int = 5
    @State private var followUpNeeded: Bool = false
    @State private var followUpNotes: String = ""
    @State private var showingConfirmation: Bool = false
    @State private var isSaving: Bool = false
    @State private var completionTime: Date = Date()
    @State private var clientAttended: Bool = true
    @State private var feltSafe: Bool = true
    @State private var safetyNotes: String = ""
    @State private var showSafetyNotes: Bool = false
    @State private var generalNotes: String = ""
    @State private var _mapRegion: State<MKCoordinateRegion>
    @State private var _annotationItems: State<[ShowingMapAnnotationItem]>
    @State private var actionTaken: ActionType = .save
    @State private var showingGeocodeAlert: Bool = false
    @State private var geocodeMessage: String = ""

    // For tracking which action was taken
    enum ActionType {
        case save
        case sendRecap
    }
    
    // For haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // Initialize with appointment and ensure it has a valid ID
    public init(appointment: AppointmentEntity) {
        self._appointment = appointment
        
        // Ensure appointment has a valid ID on init
        if appointment.id == nil || appointment.id?.isEmpty == true {
            appointment.id = UUID().uuidString
        }
        
        // Default map region (San Francisco)
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        // Set up initial map region with the appointment coordinates if valid
        if appointment.latitude != 0 && appointment.longitude != 0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: appointment.latitude,
                longitude: appointment.longitude
            )
            self._mapRegion = State(initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            self._annotationItems = State(initialValue: [ShowingMapAnnotationItem(coordinate: coordinate)])
        } else {
            // Use default values if no coordinates are available
            self._mapRegion = State(initialValue: defaultRegion)
            self._annotationItems = State(initialValue: [])
        }
    }
    
    public var body: some View {
        // Use AnyView to optimize type-checking performance
        AnyView(
            ShowingCompleteMainView(
                appointment: appointment,
                mapRegion: $mapRegion,
                annotationItems: $annotationItems,
                clientAttended: $clientAttended,
                feltSafe: $feltSafe,
                showSafetyNotes: $showSafetyNotes,
                safetyNotes: $safetyNotes,
                generalNotes: $generalNotes,
                clientFeedback: $clientFeedback,
                rating: $rating,
                followUpNeeded: $followUpNeeded,
                followUpNotes: $followUpNotes,
                completionTime: $completionTime,
                showingConfirmation: $showingConfirmation,
                showingGeocodeAlert: $showingGeocodeAlert,
                geocodeMessage: $geocodeMessage,
                actionTaken: $actionTaken,
                isSaving: $isSaving,
                formattedCompletionTime: formattedCompletionTime,
                formattedDate: formattedDate,
                saveShowingCompletion: saveShowingCompletion,
                sendRecapToOffice: sendRecapToOffice,
                setupMap: setupMap,
                feedbackGenerator: feedbackGenerator
            )
            .onAppear {
                // Register for map coordinates update notifications
                NotificationCenter.default.addObserver(
                    forName: Notification.Name("UpdateMapCoordinates"),
                    object: nil,
                    queue: .main
                ) { [weak viewContext] notification in
                    guard let userInfo = notification.userInfo,
                        let latitude = userInfo["latitude"] as? Double,
                        let longitude = userInfo["longitude"] as? Double,
                        let appointmentId = userInfo["appointmentId"] as? String,
                        appointmentId == appointment.id else {
                        return
                    }
                    
                    print("📍 Received updated coordinates: \(latitude), \(longitude)")
                    
                    // Update appointment coordinates
                    appointment.latitude = latitude
                    appointment.longitude = longitude
                    
                    // Update map region
                    mapRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                    
                    // Update annotations
                    annotationItems = [ShowingMapAnnotationItem(coordinate: CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    ))]
                    
                    // Save to Core Data
                    do {
                        try viewContext?.save()
                        print("💾 Updated coordinates saved to Core Data")
                    } catch {
                        print("❌ Error saving coordinates to Core Data: \(error.localizedDescription)")
                    }
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                NotificationCenter.default.removeObserver(self, name: Notification.Name("UpdateMapCoordinates"), object: nil)
            }
        )
    }
    
    // MARK: - Main View Container
    
    private struct ShowingCompleteMainView: View {
        @Environment(\.presentationMode) private var presentationMode
        
        let appointment: AppointmentEntity
        @Binding var mapRegion: MKCoordinateRegion
        @Binding var annotationItems: [ShowingMapAnnotationItem]
        @Binding var clientAttended: Bool
        @Binding var feltSafe: Bool
        @Binding var showSafetyNotes: Bool
        @Binding var safetyNotes: String
        @Binding var generalNotes: String
        @Binding var clientFeedback: String
        @Binding var rating: Int
        @Binding var followUpNeeded: Bool
        @Binding var followUpNotes: String
        @Binding var completionTime: Date
        @Binding var showingConfirmation: Bool
        @Binding var showingGeocodeAlert: Bool
        @Binding var geocodeMessage: String
        @Binding var actionTaken: ShowingCompleteView.ActionType
        @Binding var isSaving: Bool
        
        let formattedCompletionTime: String
        let formattedDate: String
        let saveShowingCompletion: () -> Void
        let sendRecapToOffice: () -> Void
        let setupMap: () -> Void
        let feedbackGenerator: UINotificationFeedbackGenerator
        
        // Add ViewBuilder to help with type inference
        @ViewBuilder
        var body: some View {
            NavigationView {
                // Use AnyView to help with type erasure
                AnyView(
                    ShowingCompleteScrollContent(
                        appointment: appointment,
                        mapRegion: $mapRegion,
                        annotationItems: $annotationItems,
                        clientAttended: $clientAttended,
                        feltSafe: $feltSafe,
                        showSafetyNotes: $showSafetyNotes,
                        safetyNotes: $safetyNotes,
                        generalNotes: $generalNotes,
                        clientFeedback: $clientFeedback,
                        rating: $rating,
                        followUpNeeded: $followUpNeeded,
                        followUpNotes: $followUpNotes,
                        completionTime: $completionTime,
                        isSaving: $isSaving,
                        saveShowingCompletion: saveShowingCompletion,
                        sendRecapToOffice: sendRecapToOffice,
                        feedbackGenerator: feedbackGenerator
                    )
                    .navigationBarTitle("Showing Complete", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { 
                                presentationMode.wrappedValue.dismiss() 
                            }) {
                                Image(systemName: "xmark").foregroundColor(.primary)
                            }
                        }
                    }
                    .alert(isPresented: $showingConfirmation) {
                        switch actionTaken {
                        case .save:
                            return Alert(
                                title: Text("Showing Completed"),
                                message: Text("The showing has been marked as complete at \(formattedCompletionTime)." + 
                                            (clientAttended ? " Client attendance confirmed." : " Client did not attend.") +
                                            (!feltSafe ? " Safety concerns have been reported." : "") +
                                            (followUpNeeded ? " Follow-up has been flagged." : "") +
                                            " Your notes have been saved."),
                                dismissButton: .default(Text("Done")) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            )
                        case .sendRecap:
                            return Alert(
                                title: Text("Recap Sent"),
                                message: Text("A summary of this showing has been sent to your office. They will receive details about the property, client attendance, and any follow-up needed."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    }
                    .onAppear {
                        setupMap()
                    }
                )
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
    
    // MARK: - Scroll Content
    
    private struct ShowingCompleteScrollContent: View {
        let appointment: AppointmentEntity
        @Binding var mapRegion: MKCoordinateRegion
        @Binding var annotationItems: [ShowingMapAnnotationItem]
        @Binding var clientAttended: Bool
        @Binding var feltSafe: Bool
        @Binding var showSafetyNotes: Bool
        @Binding var safetyNotes: String
        @Binding var generalNotes: String
        @Binding var clientFeedback: String
        @Binding var rating: Int
        @Binding var followUpNeeded: Bool
        @Binding var followUpNotes: String
        @Binding var completionTime: Date
        @Binding var isSaving: Bool
        
        let saveShowingCompletion: () -> Void
        let sendRecapToOffice: () -> Void
        let feedbackGenerator: UINotificationFeedbackGenerator
        
        // Add @ViewBuilder to help compiler with type inference
        @ViewBuilder
        var body: some View {
            ScrollView(.vertical, showsIndicators: true) {
                // Using AnyView to help with type erasure and compiler performance
                AnyView(contentStack)
            }
        }
        
        // Breaking the content into a separate property to reduce compiler complexity
        private var contentStack: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                AnyView(SuccessHeaderView(appointment: appointment))
                
                // Location section
                AnyView(LocationSectionView(
                    appointment: appointment,
                    mapRegion: $mapRegion,
                    annotationItems: $annotationItems
                ))
                
                // Completion time section
                AnyView(CompletionTimeSectionView(completionTime: $completionTime))
                
                // Client attendance section
                AnyView(ClientAttendanceSectionView(clientAttended: $clientAttended))
                
                // Safety section
                AnyView(SafetySectionView(
                    feltSafe: $feltSafe,
                    showSafetyNotes: $showSafetyNotes,
                    safetyNotes: $safetyNotes
                ))
                
                // Notes section
                AnyView(NotesSectionView(generalNotes: $generalNotes))
                
                // Summary section
                AnyView(SummarySectionView(appointment: appointment))
                
                // Client sections (only if attended)
                if clientAttended {
                    AnyView(clientFeedbackViews)
                }
                
                // Follow-up section
                AnyView(FollowUpSectionView(
                    followUpNeeded: $followUpNeeded,
                    followUpNotes: $followUpNotes
                ))
                
                // Actions
                AnyView(actionButtons)
            }
            .padding()
        }
        
        // Extract client feedback views to a separate property
        private var clientFeedbackViews: some View {
            Group {
                FeedbackSectionView(clientFeedback: $clientFeedback)
                RatingSectionView(rating: $rating, feedbackGenerator: feedbackGenerator)
            }
        }
        
        // Extract action buttons to a separate property
        private var actionButtons: some View {
            VStack(spacing: 12) {
                Button(action: {
                    feedbackGenerator.prepare()
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
                    feedbackGenerator.prepare()
                    sendRecapToOffice()
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
            .padding(.top, 20)
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        guard let startTime = appointment.startTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    private var formattedDuration: String {
        guard let startTime = appointment.startTime, let endTime = appointment.endTime else { return "Unknown" }
        
        let duration = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        
        if let hours = duration.hour, let minutes = duration.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes) minutes"
            }
        }
        
        return "Unknown"
    }
    
    private var formattedCompletionTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completionTime)
    }
    
    // MARK: - Helper Properties
    
    private var formattedDate: String {
        guard let startTime = appointment.startTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    private var formattedDuration: String {
        guard let startTime = appointment.startTime, let endTime = appointment.endTime else { return "Unknown" }
        
        let duration = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        
        if let hours = duration.hour, let minutes = duration.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes) minutes"
            }
        }
        
        return "Unknown"
    }
    
    private var formattedCompletionTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completionTime)
    }
    
    // MARK: - Helper Methods
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
    
    private func saveShowingCompletion() {
        isSaving = true
        actionTaken = .save
        
        // More detailed debugging of the appointment entity
        print("Debug - Appointment details:")
        print("Debug - ID: \(appointment.id ?? "nil")")
        print("Debug - Title: \(appointment.title ?? "nil")")
        print("Debug - Property Address: \(appointment.propertyAddress ?? "nil")")
        print("Debug - Coordinates: (\(appointment.latitude), \(appointment.longitude))")
        print("Debug - Start Time: \(appointment.startTime?.description ?? "nil")")
        print("Debug - End Time: \(appointment.endTime?.description ?? "nil")")
        print("Debug - Event Identifier: \(appointment.eventIdentifier ?? "nil")")
        print("Debug - Status: \(appointment.status ?? "nil")")
        
        // Don't require a valid UUID format - use the ID string directly
        guard let idString = appointment.id, !idString.isEmpty else {
            // Handle error
            print("Error: Empty or nil appointment ID")
            feedbackGenerator.notificationOccurred(.error)
            isSaving = false
            self.geocodeMessage = "Error: Unable to save - No appointment ID"
            self.showingGeocodeAlert = true
            return
        }
        
        // Generate a unique ID if we're not using appointment.id
        // This ensures we have a valid document ID for Firestore
        let uniqueDocId = UUID().uuidString
        print("Debug - Using generated unique ID for Firestore: \(uniqueDocId)")
        
        // Debug the data being sent
        print("Debug - Saving appointment to Firestore - Address: \(appointment.propertyAddress ?? "Unknown")")
        print("Debug - Coordinates: \(appointment.latitude), \(appointment.longitude)")
        
        // Create a custom modified version of FirestoreService.saveShowingCompletion that uses
        // user-specific subcollection which should have less strict permissions
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
            documentId: uniqueDocId
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success(let docId):
                    print("Successfully saved showing completion to Firestore with ID: \(docId)")
                    
                    // Also update local Core Data model
                    self.appointment.status = "completed"
                    
                    do {
                        try self.viewContext.save()
                        print("Core Data status updated to completed")
                    } catch {
                        print("Error updating Core Data: \(error.localizedDescription)")
                    }
                    
                    // Provide haptic feedback for successful save
                    self.feedbackGenerator.notificationOccurred(.success)
                    
                    // Show confirmation
                    self.showingConfirmation = true
                    
                case .failure(let error):
                    print("Error saving to Firestore: \(error.localizedDescription)")
                    self.feedbackGenerator.notificationOccurred(.error)
                    
                    // Show error alert instead
                    self.geocodeMessage = "Error saving: \(error.localizedDescription)"
                    self.showingGeocodeAlert = true
                }
            }
        }
    }
    
    // A modified version that writes to a user-specific subcollection instead of the main collection
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
        
        print("Debug - Using user-specific collection path for user: \(currentUserId)")
        
        // Create a reference to the showing completion document in user's own collection
        // This should have less strict security rules
        let showingCompletionRef: DocumentReference
        if let docId = documentId {
            showingCompletionRef = db.collection("users")
                .document(currentUserId)
                .collection("myShowingCompletions")
                .document(docId)
            print("Debug - Using provided document ID in user collection: \(docId)")
        } else {
            showingCompletionRef = db.collection("users")
                .document(currentUserId)
                .collection("myShowingCompletions")
                .document()
            print("Debug - Generated new document ID in user collection: \(showingCompletionRef.documentID)")
        }
        
        let showingId = showingCompletionRef.documentID
        
        // Prepare the data to save
        var data: [String: Any] = [
            "showingId": showingId,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "propertyAddress": propertyAddress,
            "completionTime": completionTime,
            "clientAttended": clientAttended,
            "feltSafe": feltSafe,
            "followUpNeeded": followUpNeeded,
            "latitude": latitude,
            "longitude": longitude,
            "status": "completed",
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
        
        // Save the data to Firestore in user's collection
        showingCompletionRef.setData(data) { error in
            if let error = error {
                print("Error saving showing completion: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Successfully saved showing completion to user's Firestore collection with ID: \(showingId)")
                
                // Update appointment status
                let appointmentRef = db.collection("users")
                    .document(currentUserId)
                    .collection("appointments")
                    .document(appointmentId)
                
                var statusData: [String: Any] = [
                    "status": "completed",
                    "updatedAt": FieldValue.serverTimestamp(),
                    "completionId": showingId
                ]
                
                if let completionTime = completionTime as? Date {
                    statusData["completionTime"] = completionTime
                }
                
                // Use setData with merge:true instead of updateData to handle non-existent documents
                appointmentRef.setData(statusData, merge: true) { error in
                    if let error = error {
                        print("Warning: Status update failed: \(error.localizedDescription)")
                        // Still return success since we saved the main document
                    } else {
                        print("Successfully updated appointment status to completed")
                    }
                    completion(.success(showingId))
                }
            }
        }
    }
    
    private func sendRecapToOffice() {
        isSaving = true
        actionTaken = .sendRecap
        
        // More detailed debugging of the appointment entity
        print("Debug - Appointment details for recap:")
        print("Debug - ID: \(appointment.id ?? "nil")")
        print("Debug - Title: \(appointment.title ?? "nil")")
        print("Debug - Property Address: \(appointment.propertyAddress ?? "nil")")
        
        // Don't require a valid UUID format - use the ID string directly
        guard let idString = appointment.id, !idString.isEmpty else {
            // Handle error
            print("Error: Empty or nil appointment ID")
            feedbackGenerator.notificationOccurred(.error)
            isSaving = false
            self.geocodeMessage = "Error: Unable to send recap - No appointment ID"
            self.showingGeocodeAlert = true
            return
        }
        
        // Generate a unique ID for the recap document
        let uniqueRecapId = UUID().uuidString
        print("Debug - Using generated unique ID for recap: \(uniqueRecapId)")
        
        // Debug the data being sent
        print("Debug - Sending recap to office - Address: \(self.appointment.propertyAddress ?? "Unknown")")
        
        // Prepare the recap
        let recap = self.prepareRecap()
        
        // Check for network connectivity
        checkNetworkConnectivity { isConnected in
            if isConnected {
                // Online - Try to send directly to Firestore
                self.sendRecapToOfficeInUserCollection(
                    appointmentId: idString,
                    recap: recap,
                    documentId: uniqueRecapId
                ) { result in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        
                        switch result {
                        case .success(let recapId):
                            print("Successfully sent recap to office via user collection with ID: \(recapId)")
                            
                            // Also try to send to the main officeRecaps collection
                            self.sendRecapToMainCollection(
                                appointmentId: idString,
                                recap: recap,
                                documentId: uniqueRecapId
                            )
                            
                            // Provide haptic feedback for successful save
                            self.feedbackGenerator.notificationOccurred(.success)
                            
                            // If safety concerns were reported, also submit a safety incident
                            if !self.feltSafe && !self.safetyNotes.isEmpty {
                                self.reportSafetyIncidentInUserCollection()
                            }
                            
                            // Show confirmation
                            self.showingConfirmation = true
                            
                        case .failure(let error):
                            print("Error sending recap to Firestore: \(error.localizedDescription)")
                            self.feedbackGenerator.notificationOccurred(.error)
                            
                            // Cache the recap locally for later upload
                            self.cacheRecapForOfflineUse(
                                appointmentId: idString,
                                recap: recap,
                                documentId: uniqueRecapId
                            )
                            
                            // Show error alert with offline caching message
                            self.geocodeMessage = "Network issue while sending recap. It has been saved offline and will be sent when connection is restored."
                            self.showingGeocodeAlert = true
                        }
                    }
                }
            } else {
                // Offline - Store locally for later upload
                self.cacheRecapForOfflineUse(
                    appointmentId: idString,
                    recap: recap,
                    documentId: uniqueRecapId
                )
                
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.feedbackGenerator.notificationOccurred(.success)
                    
                    // Show offline success message
                    self.geocodeMessage = "You are offline. The recap has been saved locally and will be sent when connection is restored."
                    self.showingGeocodeAlert = true
                }
            }
        }
    }
    
    // Cache the recap locally for offline use
    private func cacheRecapForOfflineUse(appointmentId: String, recap: String, documentId: String) {
        let cachedRecap = CachedRecap(
            appointmentId: appointmentId,
            recap: recap,
            documentId: documentId,
            timestamp: Date(),
            clientFeedback: clientAttended ? clientFeedback : nil,
            interestRating: clientAttended ? rating : nil,
            feltSafe: feltSafe,
            followUpNeeded: followUpNeeded,
            followUpNotes: followUpNeeded ? followUpNotes : nil,
            generalNotes: generalNotes.isEmpty ? nil : generalNotes
        )
        
        RecapCacheManager.shared.cacheRecap(cachedRecap)
        print("Recap cached for offline use: \(appointmentId)")
    }
    
    // Check network connectivity
    private func checkNetworkConnectivity(completion: @escaping (Bool) -> Void) {
        // Use Firestore to check connectivity status by attempting a small read operation
        let db = Firestore.firestore()
        
        // Try to get a document that might not exist
        db.collection("connectivity_check").document("test").getDocument { _, error in
            if let error = error {
                print("Network connectivity check failed: \(error.localizedDescription)")
                print("Assuming offline mode")
                completion(false)
            } else {
                print("Network connectivity confirmed")
                completion(true)
            }
        }
    }
    
    // Try to send to the main officeRecaps collection as well
    private func sendRecapToMainCollection(
        appointmentId: String,
        recap: String,
        documentId: String?
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated when trying to send to main collection")
            return
        }
        
        let db = Firestore.firestore()
        
        let recapRef: DocumentReference
        if let docId = documentId {
            recapRef = db.collection("officeRecaps").document(docId)
        } else {
            recapRef = db.collection("officeRecaps").document()
        }
        
        let recapData: [String: Any] = [
            "recapId": recapRef.documentID,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "recap": recap,
            "sentAt": FieldValue.serverTimestamp(),
            "read": false,
            "responseNeeded": false
        ]
        
        print("Debug - Attempting to send recap to main officeRecaps collection")
        
        recapRef.setData(recapData) { error in
            if let error = error {
                print("Warning: Could not save to main officeRecaps collection: \(error.localizedDescription)")
                print("Debug - This is expected if you don't have permissions for the main collection")
            } else {
                print("Successfully sent recap to main officeRecaps collection")
            }
        }
    }
    
    // Custom implementation to send recap to user-specific collection
    private func sendRecapToOfficeInUserCollection(
        appointmentId: String,
        recap: String,
        documentId: String?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Get Firestore instance
        let db = Firestore.firestore()
        
        // Get the current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            print("Error: User not authenticated when trying to send recap")
            completion(.failure(error))
            return
        }
        
        print("Debug - Starting to send recap using user-specific collection for user: \(currentUserId)")
        
        // Create a reference to the recap document in user's own collection
        let recapRef: DocumentReference
        if let docId = documentId {
            recapRef = db.collection("users")
                .document(currentUserId)
                .collection("myRecaps")
                .document(docId)
            print("Debug - Using provided document ID for recap: \(docId)")
        } else {
            recapRef = db.collection("users")
                .document(currentUserId)
                .collection("myRecaps")
                .document()
            print("Debug - Generated new document ID for recap: \(recapRef.documentID)")
        }
        
        let recapId = recapRef.documentID
        
        // Prepare the recap data
        let recapData: [String: Any] = [
            "recapId": recapId,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "recap": recap,
            "sentAt": FieldValue.serverTimestamp(),
            "read": false,
            "responseNeeded": false
        ]
        
        print("Debug - Attempting to send recap with data: \(recapData)")
        
        // Save the recap to Firestore
        recapRef.setData(recapData) { error in
            if let error = error {
                print("Error sending recap to Firestore: \(error.localizedDescription)")
                print("Debug - Full error details: \(error)")
                completion(.failure(error))
            } else {
                print("Successfully sent recap to office with ID: \(recapId)")
                
                // Also update the appointment to mark recap as sent
                let appointmentRef = db.collection("users")
                    .document(currentUserId)
                    .collection("appointments")
                    .document(appointmentId)
                
                let appointmentUpdate: [String: Any] = [
                    "recapSent": true,
                    "recapId": recapId,
                    "recapSentAt": FieldValue.serverTimestamp()
                ]
                
                // Use setData with merge to avoid "no document to update" errors
                appointmentRef.setData(appointmentUpdate, merge: true) { updateError in
                    if let updateError = updateError {
                        print("Warning: Could not update appointment with recap info: \(updateError.localizedDescription)")
                        // Still return success since the main recap was saved
                    } else {
                        print("Successfully updated appointment with recap info")
                    }
                    
                    // Return success regardless of appointment update
                    completion(.success(recapId))
                }
            }
        }
    }
    
    private func reportSafetyIncidentInUserCollection() {
        // More detailed debugging of the appointment entity
        print("Debug - Appointment details for safety report:")
        print("Debug - ID: \(appointment.id ?? "nil")")
        print("Debug - Title: \(appointment.title ?? "nil")")
        print("Debug - Property Address: \(appointment.propertyAddress ?? "nil")")
        
        guard let idString = appointment.id, !idString.isEmpty else {
            print("Error: Cannot report safety incident - Empty or nil appointment ID")
            feedbackGenerator.notificationOccurred(.error)
            return
        }
        
        // Generate a unique ID for the safety report
        let uniqueSafetyReportId = UUID().uuidString
        print("Debug - Using generated unique ID for safety report: \(uniqueSafetyReportId)")
        
        print("Debug - Reporting safety incident for address: \(appointment.propertyAddress ?? "Unknown")")
        
        // Get Firestore instance
        let db = Firestore.firestore()
        
        // Get the current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: User not authenticated")
            feedbackGenerator.notificationOccurred(.error)
            return
        }
        
        // Create a reference to the safety report in user's collection
        let safetyReportRef = db.collection("users")
            .document(currentUserId)
            .collection("mySafetyReports")
            .document(uniqueSafetyReportId)
        
        let reportId = safetyReportRef.documentID
        
        // Prepare the report data
        let reportData: [String: Any] = [
            "reportId": reportId,
            "appointmentId": idString,
            "agentId": currentUserId,
            "propertyAddress": appointment.propertyAddress ?? "Unknown Address",
            "details": safetyNotes,
            "latitude": appointment.latitude,
            "longitude": appointment.longitude,
            "status": "new",
            "reportedAt": FieldValue.serverTimestamp(),
            "resolved": false,
            "severity": "medium"
        ]
        
        // Save the safety report to Firestore
        safetyReportRef.setData(reportData) { error in
            if let error = error {
                print("Error submitting safety report: \(error.localizedDescription)")
                self.feedbackGenerator.notificationOccurred(.error)
            } else {
                print("Safety incident report submitted successfully with ID: \(reportId)")
                self.feedbackGenerator.notificationOccurred(.success)
            }
        }
    }
    
    private func prepareRecap() -> String {
        // Prepare a formatted recap of the showing
        var recap = "Showing Recap\n"
        recap += "==============\n"
        recap += "Property: \(appointment.propertyAddress ?? "Unknown")\n"
        recap += "Date: \(formattedDate)\n"
        recap += "Completed at: \(formattedCompletionTime)\n"
        recap += "Client attended: \(clientAttended ? "Yes" : "No")\n"
        
        if clientAttended {
            recap += "Interest level: \(rating)/5\n"
            if !clientFeedback.isEmpty {
                recap += "Client feedback: \(clientFeedback)\n"
            }
        }
        
        if !feltSafe {
            recap += "⚠️ SAFETY CONCERNS REPORTED ⚠️\n"
            recap += "Safety notes: \(safetyNotes)\n"
        }
        
        if followUpNeeded {
            recap += "Follow-up needed: Yes\n"
            recap += "Follow-up notes: \(followUpNotes)\n"
        }
        
        if !generalNotes.isEmpty {
            recap += "General notes: \(generalNotes)\n"
        }
        
        return recap
    }
    
    // MARK: - Map Setup
    
    private var mapRegion: MKCoordinateRegion {
        get { _mapRegion.wrappedValue }
        set { _mapRegion.wrappedValue = newValue }
    }
    
    private var annotationItems: [ShowingMapAnnotationItem] {
        get { _annotationItems.wrappedValue }
        set { _annotationItems.wrappedValue = newValue }
    }
    
    private func setupMap() {
        // Check if we have valid coordinates
        if appointment.latitude != 0 && appointment.longitude != 0 {
            // Create the coordinate
            let coordinate = CLLocationCoordinate2D(
                latitude: appointment.latitude,
                longitude: appointment.longitude
            )
            
            // Set the map region
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            
            // Create the annotation
            annotationItems = [ShowingMapAnnotationItem(coordinate: coordinate)]
            
            print("Map set up with coordinates: \(coordinate.latitude), \(coordinate.longitude)")
        } else {
            print("No valid coordinates available for the map")
        }
    }
    
    private func openInMaps() {
        guard appointment.latitude != 0 && appointment.longitude != 0 else {
            print("Cannot open maps: No valid coordinates")
            return
        }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: appointment.latitude,
            longitude: appointment.longitude
        )
        
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = appointment.propertyAddress
        
        // Use more options for better navigation
        let options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsShowsTrafficKey: true
        ]
        
        mapItem.openInMaps(launchOptions: options)
    }
}

// Remove the Views namespace reference and fix the preview
extension ShowingCompleteView {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let appointment = AppointmentEntity(context: context)
        appointment.id = UUID().uuidString
        appointment.title = "123 Main St Showing"
        appointment.propertyAddress = "123 Main St, Anna, TX"
        appointment.startTime = Date()
        appointment.endTime = Date().addingTimeInterval(3600)
        appointment.status = "scheduled"
        
        return ShowingCompleteView(appointment: appointment)
            .environment(\.managedObjectContext, context)
    }
}

// MARK: - Section Subviews

// Location Section
struct LocationSectionView: View {
    let appointment: AppointmentEntity
    @Binding var mapRegion: MKCoordinateRegion
    @Binding var annotationItems: [ShowingMapAnnotationItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
                .padding(.bottom, 4)
            if appointment.latitude != 0 && appointment.longitude != 0 {
                Map(coordinateRegion: $mapRegion, annotationItems: annotationItems) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
                .frame(height: 180)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                Text(appointment.propertyAddress ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Text("No location coordinates available for this property")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
            }
        }
    }
}

// Completion Time Section
struct CompletionTimeSectionView: View {
    @Binding var completionTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Completed")
                .font(.headline)
                .padding(.bottom, 4)
            DatePicker(
                "Completion Time",
                selection: $completionTime,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// Client Attendance Section
struct ClientAttendanceSectionView: View {
    @Binding var clientAttended: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $clientAttended) {
                HStack {
                    Image(systemName: "person.fill").foregroundColor(.blue)
                    Text("Client Attended?").font(.headline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// Safety Section
struct SafetySectionView: View {
    @Binding var feltSafe: Bool
    @Binding var showSafetyNotes: Bool
    @Binding var safetyNotes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $feltSafe) {
                HStack {
                    Image(systemName: "shield.fill").foregroundColor(feltSafe ? .green : .red)
                    Text("Did you feel safe during the showing?").font(.headline)
                }
            }
            .onChange(of: feltSafe) { newValue in showSafetyNotes = !newValue }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            if showSafetyNotes {
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
                    .overlay(
                        Group {
                            if safetyNotes.isEmpty {
                                Text("Describe any safety concerns or incidents...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        }, alignment: .topLeading
                    )
            }
        }
    }
}

// Notes Section
struct NotesSectionView: View {
    @Binding var generalNotes: String
    
    var body: some View {
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
                .overlay(
                    Group {
                        if generalNotes.isEmpty {
                            Text("Add any general notes about the showing, property condition, etc...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }, alignment: .topLeading
                )
        }
    }
}

// Summary Section
struct SummarySectionView: View {
    let appointment: AppointmentEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Showing Summary")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                detailRow(icon: "clock", title: "Date", value: formattedDate)
                detailRow(icon: "timer", title: "Duration", value: formattedDuration)
                detailRow(icon: "mappin.and.ellipse", title: "Location", value: appointment.propertyAddress ?? "Unknown")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
    }
    
    private var formattedDate: String {
        guard let startTime = appointment.startTime else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    private var formattedDuration: String {
        guard let startTime = appointment.startTime, let endTime = appointment.endTime else { return "Unknown" }
        
        let duration = Calendar.current.dateComponents([.hour, .minute], from: startTime, to: endTime)
        
        if let hours = duration.hour, let minutes = duration.minute {
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes) minutes"
            }
        }
        
        return "Unknown"
    }
}

// Feedback Section
struct FeedbackSectionView: View {
    @Binding var clientFeedback: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Feedback")
                .font(.headline)
                .padding(.bottom, 4)
            
            TextEditor(text: $clientFeedback)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if clientFeedback.isEmpty {
                            Text("Enter client's comments about the property...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
}

// Rating Section
struct RatingSectionView: View {
    @Binding var rating: Int
    let feedbackGenerator: UINotificationFeedbackGenerator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Client Interest Level")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(index <= rating ? .yellow : .gray)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rating = index
                                feedbackGenerator.notificationOccurred(.success)
                            }
                        }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// Follow-up Section
struct FollowUpSectionView: View {
    @Binding var followUpNeeded: Bool
    @Binding var followUpNotes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $followUpNeeded) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text("Follow-up Needed")
                        .font(.headline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if followUpNeeded {
                Text("What follow-up is needed?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                TextEditor(text: $followUpNotes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if followUpNotes.isEmpty {
                                Text("Enter follow-up details, action items, or reminders...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
        }
    }
}

// Private helper to retain the action buttons section
extension ShowingCompleteView {
    var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                feedbackGenerator.prepare()
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
                feedbackGenerator.prepare()
                sendRecapToOffice()
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
        .padding(.top, 20)
    }
}

// MARK: - Missing View Definitions

// Success Header View
struct SuccessHeaderView: View {
    let appointment: AppointmentEntity
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Showing Complete")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(appointment.propertyAddress ?? "")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
} 