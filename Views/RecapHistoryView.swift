import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RecapHistoryView: View {
    @State private var recaps: [RecapDisplayItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var hasOfflineRecaps = false
    @State private var syncingOfflineRecaps = false
    @State private var showingRecapDetail = false
    @State private var selectedRecap: RecapDisplayItem?
    
    // For haptic feedback
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    // Structure for displaying recaps in the list
    struct RecapDisplayItem: Identifiable {
        let id: String
        let propertyAddress: String
        let sentDate: Date
        let read: Bool
        let recap: String
        let appointmentId: String
        let isOffline: Bool
        
        // For sorting
        static func < (lhs: RecapDisplayItem, rhs: RecapDisplayItem) -> Bool {
            return lhs.sentDate > rhs.sentDate
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView("Loading recaps...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if recaps.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        if hasOfflineRecaps {
                            offlineRecapsBanner
                        }
                        
                        List {
                            ForEach(recaps) { recap in
                                RecapRowView(recap: recap)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecap = recap
                                        showingRecapDetail = true
                                    }
                            }
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationBarTitle("Sent Recaps", displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if hasOfflineRecaps {
                        Button(action: syncOfflineRecaps) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync")
                            }
                        }
                        .disabled(syncingOfflineRecaps)
                    }
                }
            }
            .sheet(isPresented: $showingRecapDetail) {
                if let selectedRecap = selectedRecap {
                    RecapDetailView(recap: selectedRecap)
                }
            }
            .alert(isPresented: $showingError) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                loadRecaps()
            }
        }
    }
    
    // MARK: - Subviews
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Recaps Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your sent recaps will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // Banner for offline recaps
    private var offlineRecapsBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            
            Text("\(RecapCacheManager.shared.getRecaps().count) recaps waiting to sync")
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            if syncingOfflineRecaps {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Button(action: syncOfflineRecaps) {
                    Text("Sync Now")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(Color.blue)
    }
    
    // MARK: - Methods
    
    // Load recaps from Firestore
    private func loadRecaps() {
        isLoading = true
        recaps = []
        
        // Check for offline recaps
        let offlineRecaps = RecapCacheManager.shared.getRecaps()
        hasOfflineRecaps = !offlineRecaps.isEmpty
        
        // If offline, just show cached recaps
        if hasOfflineRecaps {
            // Convert offline recaps to display items
            for cachedRecap in offlineRecaps {
                let displayItem = RecapDisplayItem(
                    id: cachedRecap.cacheId,
                    propertyAddress: extractPropertyAddress(from: cachedRecap.recap),
                    sentDate: cachedRecap.timestamp,
                    read: false,
                    recap: cachedRecap.recap,
                    appointmentId: cachedRecap.appointmentId,
                    isOffline: true
                )
                recaps.append(displayItem)
            }
        }
        
        // Load recaps from Firestore
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "You need to be signed in to view recaps"
            showingError = true
            return
        }
        
        // First check user-specific collection
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUserId)
            .collection("myRecaps")
            .order(by: "sentAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading recaps: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load recaps: \(error.localizedDescription)"
                        self.showingError = true
                        self.isLoading = false
                    }
                    return
                }
                
                if let snapshot = snapshot {
                    var newRecaps: [RecapDisplayItem] = []
                    
                    for document in snapshot.documents {
                        let data = document.data()
                        
                        // Extract data
                        let id = document.documentID
                        let appointmentId = data["appointmentId"] as? String ?? ""
                        let recap = data["recap"] as? String ?? ""
                        let read = data["read"] as? Bool ?? false
                        
                        // Get date
                        let timestamp: Date
                        if let sentAt = data["sentAt"] as? Timestamp {
                            timestamp = sentAt.dateValue()
                        } else {
                            timestamp = Date()
                        }
                        
                        // Extract address from recap
                        let propertyAddress = self.extractPropertyAddress(from: recap)
                        
                        // Create recap item
                        let recapItem = RecapDisplayItem(
                            id: id,
                            propertyAddress: propertyAddress,
                            sentDate: timestamp,
                            read: read,
                            recap: recap,
                            appointmentId: appointmentId,
                            isOffline: false
                        )
                        
                        newRecaps.append(recapItem)
                    }
                    
                    // Also try to check the main officeRecaps collection
                    self.loadMainCollectionRecaps(currentUserId: currentUserId) { mainRecaps in
                        // Merge with user collection recaps, removing duplicates by appointmentId
                        let combinedRecaps = self.mergeRecaps(userRecaps: newRecaps, mainRecaps: mainRecaps)
                        
                        DispatchQueue.main.async {
                            // Merge with offline recaps
                            let allRecaps = self.mergeWithOfflineRecaps(firebaseRecaps: combinedRecaps)
                            
                            // Sort recaps by date
                            self.recaps = allRecaps.sorted { $0.sentDate > $1.sentDate }
                            self.isLoading = false
                        }
                    }
                }
            }
    }
    
    // Load recaps from the main officeRecaps collection
    private func loadMainCollectionRecaps(currentUserId: String, completion: @escaping ([RecapDisplayItem]) -> Void) {
        let db = Firestore.firestore()
        db.collection("officeRecaps")
            .whereField("agentId", isEqualTo: currentUserId)
            .order(by: "sentAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                var mainRecaps: [RecapDisplayItem] = []
                
                if let error = error {
                    print("Error loading main collection recaps: \(error.localizedDescription)")
                    // Continue with empty array - this is expected if permissions are restricted
                    completion(mainRecaps)
                    return
                }
                
                if let snapshot = snapshot {
                    for document in snapshot.documents {
                        let data = document.data()
                        
                        // Extract data
                        let id = document.documentID
                        let appointmentId = data["appointmentId"] as? String ?? ""
                        let recap = data["recap"] as? String ?? ""
                        let read = data["read"] as? Bool ?? false
                        
                        // Get date
                        let timestamp: Date
                        if let sentAt = data["sentAt"] as? Timestamp {
                            timestamp = sentAt.dateValue()
                        } else {
                            timestamp = Date()
                        }
                        
                        // Extract address from recap
                        let propertyAddress = self.extractPropertyAddress(from: recap)
                        
                        // Create recap item
                        let recapItem = RecapDisplayItem(
                            id: id,
                            propertyAddress: propertyAddress,
                            sentDate: timestamp,
                            read: read,
                            recap: recap,
                            appointmentId: appointmentId,
                            isOffline: false
                        )
                        
                        mainRecaps.append(recapItem)
                    }
                }
                
                completion(mainRecaps)
            }
    }
    
    // Merge user collection recaps with main collection recaps
    private func mergeRecaps(userRecaps: [RecapDisplayItem], mainRecaps: [RecapDisplayItem]) -> [RecapDisplayItem] {
        var merged = userRecaps
        
        // Add recaps from main collection if they don't already exist
        for mainRecap in mainRecaps {
            if !userRecaps.contains(where: { $0.appointmentId == mainRecap.appointmentId }) {
                merged.append(mainRecap)
            }
        }
        
        return merged
    }
    
    // Merge Firebase recaps with offline recaps, filtering out duplicates
    private func mergeWithOfflineRecaps(firebaseRecaps: [RecapDisplayItem]) -> [RecapDisplayItem] {
        let offlineRecaps = RecapCacheManager.shared.getRecaps()
        var merged = firebaseRecaps
        
        // Add offline recaps if they don't exist in Firebase yet
        for offlineRecap in offlineRecaps {
            if !firebaseRecaps.contains(where: { $0.appointmentId == offlineRecap.appointmentId }) {
                let displayItem = RecapDisplayItem(
                    id: offlineRecap.cacheId,
                    propertyAddress: extractPropertyAddress(from: offlineRecap.recap),
                    sentDate: offlineRecap.timestamp,
                    read: false,
                    recap: offlineRecap.recap,
                    appointmentId: offlineRecap.appointmentId,
                    isOffline: true
                )
                merged.append(displayItem)
            }
        }
        
        return merged
    }
    
    // Extract property address from recap text
    private func extractPropertyAddress(from recap: String) -> String {
        // Look for "Property:" in the recap text
        if let range = recap.range(of: "Property:") {
            let addressStart = range.upperBound
            
            // Find the end of the address (usually a newline)
            if let endRange = recap[addressStart...].range(of: "\n") {
                let address = recap[addressStart..<endRange.lowerBound]
                return String(address).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // If no newline, take the rest of the string
                return String(recap[addressStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return "Unknown Property"
    }
    
    // Sync offline recaps to Firestore
    private func syncOfflineRecaps() {
        syncingOfflineRecaps = true
        
        // Get all cached recaps
        let cachedRecaps = RecapCacheManager.shared.getRecaps()
        if cachedRecaps.isEmpty {
            syncingOfflineRecaps = false
            hasOfflineRecaps = false
            return
        }
        
        // Create a dispatch group to track when all syncs are complete
        let dispatchGroup = DispatchGroup()
        
        // Try to upload each cached recap
        for cachedRecap in cachedRecaps {
            dispatchGroup.enter()
            
            // Attempt to send to Firestore
            sendCachedRecapToFirestore(cachedRecap) { success in
                if success {
                    // Remove from cache if successful
                    RecapCacheManager.shared.removeRecap(withId: cachedRecap.cacheId)
                }
                dispatchGroup.leave()
            }
        }
        
        // When all attempts complete, refresh the view
        dispatchGroup.notify(queue: .main) {
            self.syncingOfflineRecaps = false
            self.hasOfflineRecaps = !RecapCacheManager.shared.getRecaps().isEmpty
            self.loadRecaps() // Reload all recaps
            
            // Provide feedback
            if !self.hasOfflineRecaps {
                self.feedbackGenerator.notificationOccurred(.success)
            }
        }
    }
    
    // Send a cached recap to Firestore
    private func sendCachedRecapToFirestore(_ cachedRecap: CachedRecap, completion: @escaping (Bool) -> Void) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let db = Firestore.firestore()
        let recapRef = db.collection("users")
            .document(currentUserId)
            .collection("myRecaps")
            .document(cachedRecap.documentId)
        
        // Prepare the data
        var recapData: [String: Any] = [
            "recapId": cachedRecap.documentId,
            "appointmentId": cachedRecap.appointmentId,
            "agentId": currentUserId,
            "recap": cachedRecap.recap,
            "sentAt": cachedRecap.timestamp,
            "read": false,
            "responseNeeded": false
        ]
        
        // Add optional fields
        if let clientFeedback = cachedRecap.clientFeedback, !clientFeedback.isEmpty {
            recapData["clientFeedback"] = clientFeedback
        }
        
        if let interestRating = cachedRecap.interestRating {
            recapData["interestRating"] = interestRating
        }
        
        if let followUpNotes = cachedRecap.followUpNotes, !followUpNotes.isEmpty {
            recapData["followUpNotes"] = followUpNotes
            recapData["followUpNeeded"] = true
        } else {
            recapData["followUpNeeded"] = cachedRecap.followUpNeeded
        }
        
        if let generalNotes = cachedRecap.generalNotes, !generalNotes.isEmpty {
            recapData["generalNotes"] = generalNotes
        }
        
        // Send to Firestore
        recapRef.setData(recapData) { error in
            if let error = error {
                print("Error syncing cached recap: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Successfully synced cached recap to Firestore")
                
                // Also update the appointment
                let appointmentRef = db.collection("users")
                    .document(currentUserId)
                    .collection("appointments")
                    .document(cachedRecap.appointmentId)
                
                let appointmentUpdate: [String: Any] = [
                    "recapSent": true,
                    "recapId": cachedRecap.documentId,
                    "recapSentAt": cachedRecap.timestamp
                ]
                
                appointmentRef.setData(appointmentUpdate, merge: true) { _ in
                    // Ignore errors here - the main recap was successfully synced
                    completion(true)
                }
            }
        }
    }
}

// MARK: - Helper Views

// Row view for a single recap
struct RecapRowView: View {
    let recap: RecapHistoryView.RecapDisplayItem
    
    var body: some View {
        HStack {
            // Icon for status
            ZStack {
                Circle()
                    .fill(recap.isOffline ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: recap.isOffline ? "wifi.slash" : "envelope.fill")
                    .foregroundColor(recap.isOffline ? .orange : recap.read ? .blue : .blue)
                    .font(.system(size: 16))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(recap.propertyAddress)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(formattedDate(recap.sentDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if recap.isOffline {
                Text("Offline")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            } else if !recap.read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 8)
    }
    
    // Format date in a readable format
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday, \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// Detailed view of a recap
struct RecapDetailView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    let recap: RecapHistoryView.RecapDisplayItem
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Property info
                    Group {
                        Text(recap.propertyAddress)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Sent: \(formattedDate(recap.sentDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if recap.isOffline {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.orange)
                                Text("This recap is saved offline and will be sent when connection is restored")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Divider()
                    }
                    
                    // Recap content
                    Group {
                        Text("Recap Content")
                            .font(.headline)
                        
                        Text(recap.recap)
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationBarTitle("Recap Details", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Close")
                    }
                }
            }
        }
    }
    
    // Format date in a readable format
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct RecapHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        RecapHistoryView()
    }
} 