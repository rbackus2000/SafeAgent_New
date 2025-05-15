import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class FirestoreService {
    static let shared = FirestoreService()
    
    fileprivate let db = Firestore.firestore()
    
    private init() {
        // Enable more detailed debug logging for Firestore
        let settings = FirestoreSettings()
        #if DEBUG
        // Enable detailed logging in debug builds
        settings.dispatchQueue = DispatchQueue.global(qos: .utility)
        #endif
        db.settings = settings
        
        print("FirestoreService initialized")
    }
    
    // MARK: - User Management
    
    /// Get the current user's ID or return nil if not authenticated
    func getCurrentUserId() -> String? {
        let userId = Auth.auth().currentUser?.uid
        print("Current Firebase user ID: \(userId ?? "nil")")
        return userId
    }
    
    /// Get the current user's profile data
    func getCurrentUserProfile(completion: @escaping (Result<[String: Any]?, Error>) -> Void) {
        guard let userId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.success(nil)) // User exists but profile not created yet
                return
            }
            
            completion(.success(document.data()))
        }
    }
    
    /// Create or update user profile information
    func updateUserProfile(
        name: String,
        email: String,
        phone: String,
        agentLicense: String? = nil,
        officeId: String? = nil,
        additionalData: [String: Any]? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let userId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        var profileData: [String: Any] = [
            "name": name,
            "email": email,
            "phone": phone,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Add optional fields
        if let agentLicense = agentLicense {
            profileData["agentLicense"] = agentLicense
        }
        
        if let officeId = officeId {
            profileData["officeId"] = officeId
        }
        
        // Merge any additional data
        if let additionalData = additionalData {
            for (key, value) in additionalData {
                profileData[key] = value
            }
        }
        
        let userRef = db.collection("users").document(userId)
        
        userRef.setData(profileData, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Showing Completion
    
    /// Save a completed showing to Firestore
    func saveShowingCompletion(
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
        clientInfo: [String: Any]? = nil,
        propertyInfo: [String: Any]? = nil,
        documentId: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        print("Debug - Starting saveShowingCompletion for user: \(currentUserId)")
        
        // Create a reference to the showing completion document directly
        // Store in the global showingCompletions collection (not nested under user)
        let showingCompletionRef: DocumentReference
        if let docId = documentId {
            showingCompletionRef = self.db.collection("showingCompletions").document(docId)
            print("Debug - Using provided document ID: \(docId)")
        } else {
            showingCompletionRef = self.db.collection("showingCompletions").document()
            print("Debug - Generated new document ID: \(showingCompletionRef.documentID)")
        }
        
        let showingId = showingCompletionRef.documentID
        
        print("Debug - Created document with ID: \(showingId)")
        
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
        
        // Add client info if provided
        if let clientInfo = clientInfo, !clientInfo.isEmpty {
            data["clientInfo"] = clientInfo
        }
        
        // Add property info if provided
        if let propertyInfo = propertyInfo, !propertyInfo.isEmpty {
            data["propertyInfo"] = propertyInfo
        }
        
        print("Debug - Saving document with data: \(data)")
        
        // Save the data to Firestore
        showingCompletionRef.setData(data) { error in
            if let error = error {
                print("Error saving showing completion: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Successfully saved showing completion to Firestore with ID: \(showingId)")
                
                // Also update the main appointment document to mark it as completed
                self.updateAppointmentStatus(
                    appointmentId: appointmentId,
                    status: "completed",
                    completionId: showingId,
                    completionTime: completionTime
                ) { result in
                    switch result {
                    case .success:
                        completion(.success(showingId))
                    case .failure(let updateError):
                        print("Warning: Completed status update failed: \(updateError.localizedDescription)")
                        // Still return success since we saved the main document
                        completion(.success(showingId))
                    }
                }
                
                // If safety concerns were reported and notes provided, create a safety report
                if !feltSafe, let safetyNotes = safetyNotes, !safetyNotes.isEmpty {
                    self.reportSafetyIncident(
                        appointmentId: appointmentId,
                        completionId: showingId,
                        propertyAddress: propertyAddress,
                        details: safetyNotes,
                        latitude: latitude,
                        longitude: longitude
                    ) { _ in
                        // Ignore the result, this is just an automatic report
                        print("Automatic safety report created from showing completion")
                    }
                }
            }
        }
    }
    
    /// Get a specific showing completion by ID
    func getShowingCompletion(
        showingId: String,
        completion: @escaping (Result<[String: Any]?, Error>) -> Void
    ) {
        let showingRef = db.collection("showingCompletions").document(showingId)
        
        showingRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.success(nil))
                return
            }
            
            completion(.success(document.data()))
        }
    }
    
    /// Get all showings completed by the current user
    func getUserShowingCompletions(
        limit: Int = 50,
        startAfter: Date? = nil,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        var query = db.collection("showingCompletions")
            .whereField("agentId", isEqualTo: currentUserId)
            .order(by: "completionTime", descending: true)
            .limit(to: limit)
        
        if let startAfter = startAfter {
            query = query.whereField("completionTime", isLessThan: startAfter)
        }
        
        query.getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let showingCompletions = documents.compactMap { $0.data() }
            completion(.success(showingCompletions))
        }
    }
    
    // MARK: - Appointment Management
    
    /// Update the status of an appointment
    func updateAppointmentStatus(
        appointmentId: String,
        status: String,
        completionId: String? = nil,
        completionTime: Date? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        // Check if the appointment exists
        let appointmentRef = db.collection("appointments").document(appointmentId)
        
        appointmentRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            var data: [String: Any] = [
                "status": status,
                "updatedAt": FieldValue.serverTimestamp(),
                "updatedBy": currentUserId
            ]
            
            if let completionTime = completionTime {
                data["completionTime"] = completionTime
            }
            
            if let completionId = completionId {
                data["completionId"] = completionId
            }
            
            // If document exists, update it
            if let document = document, document.exists {
                appointmentRef.updateData(data) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } else {
                // If document doesn't exist, create it
                // Add required fields for a new appointment
                data["appointmentId"] = appointmentId
                data["agentId"] = currentUserId
                data["createdAt"] = FieldValue.serverTimestamp()
                
                appointmentRef.setData(data) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Safety Reports
    
    /// Report a safety incident
    func reportSafetyIncident(
        appointmentId: String,
        completionId: String? = nil,
        propertyAddress: String,
        details: String,
        latitude: Double,
        longitude: Double,
        documentId: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        print("Debug - Starting reportSafetyIncident for user: \(currentUserId)")
        
        // Create a safety incident report
        let safetyReportRef: DocumentReference
        if let docId = documentId {
            safetyReportRef = self.db.collection("safetyReports").document(docId)
            print("Debug - Using provided document ID for safety report: \(docId)")
        } else {
            safetyReportRef = self.db.collection("safetyReports").document()
            print("Debug - Generated new document ID for safety report: \(safetyReportRef.documentID)")
        }
        
        let reportId = safetyReportRef.documentID
        
        var reportData: [String: Any] = [
            "reportId": reportId,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "propertyAddress": propertyAddress,
            "details": details,
            "latitude": latitude,
            "longitude": longitude,
            "status": "new",
            "reportedAt": FieldValue.serverTimestamp(),
            "resolved": false,
            "severity": "medium" // Default severity, could be adjusted based on content analysis
        ]
        
        // Link to the completion if provided
        if let completionId = completionId {
            reportData["completionId"] = completionId
        }
        
        print("Debug - Reporting safety incident with data: \(reportData)")
        
        safetyReportRef.setData(reportData) { error in
            if let error = error {
                print("Error reporting safety incident: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Successfully reported safety incident with ID: \(reportId)")
                completion(.success(reportId))
            }
        }
    }
    
    /// Get all safety reports submitted by the current user
    func getUserSafetyReports(
        limit: Int = 20,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        db.collection("safetyReports")
            .whereField("agentId", isEqualTo: currentUserId)
            .order(by: "reportedAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let reports = documents.compactMap { $0.data() }
                completion(.success(reports))
            }
    }
    
    // MARK: - Office Recap
    
    /// Send a showing recap to the office
    func sendRecapToOffice(
        appointmentId: String,
        recap: String,
        completionId: String? = nil,
        responseNeeded: Bool = false,
        documentId: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        print("Debug - Starting sendRecapToOffice for user: \(currentUserId)")
        
        // Create a reference to the recap document
        let recapRef: DocumentReference
        if let docId = documentId {
            recapRef = self.db.collection("officeRecaps").document(docId)
            print("Debug - Using provided document ID for recap: \(docId)")
        } else {
            recapRef = self.db.collection("officeRecaps").document()
            print("Debug - Generated new document ID for recap: \(recapRef.documentID)")
        }
        
        let recapId = recapRef.documentID
        
        // Prepare the recap data
        var recapData: [String: Any] = [
            "recapId": recapId,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "recap": recap,
            "sentAt": FieldValue.serverTimestamp(),
            "read": false,
            "responseNeeded": responseNeeded
        ]
        
        // Link to the completion if provided
        if let completionId = completionId {
            recapData["completionId"] = completionId
        }
        
        print("Debug - Sending recap with data: \(recapData)")
        
        // Save the recap to Firestore
        recapRef.setData(recapData) { error in
            if let error = error {
                print("Error sending recap: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Successfully sent recap to office with ID: \(recapId)")
                completion(.success(recapId))
            }
        }
    }
    
    /// Get all recaps sent by the current user
    func getUserRecaps(
        limit: Int = 20,
        completion: @escaping (Result<[[String: Any]], Error>) -> Void
    ) {
        guard let currentUserId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        db.collection("officeRecaps")
            .whereField("agentId", isEqualTo: currentUserId)
            .order(by: "sentAt", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let recaps = documents.compactMap { $0.data() }
                completion(.success(recaps))
            }
    }
    
    // MARK: - Office Management
    
    /// Get office information by ID
    func getOfficeInfo(
        officeId: String,
        completion: @escaping (Result<[String: Any]?, Error>) -> Void
    ) {
        db.collection("offices").document(officeId).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists else {
                completion(.success(nil))
                return
            }
            
            completion(.success(document.data()))
        }
    }
}

// MARK: - FirestoreService Extension for Profile Image URL
extension FirestoreService {
    func updateUserProfileImageUrl(url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = getCurrentUserId() else {
            let error = NSError(domain: "FirestoreService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        let userRef = db.collection("users").document(userId)
        userRef.setData(["profileImageUrl": url], merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
} 

