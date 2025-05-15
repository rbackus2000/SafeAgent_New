import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService {
    static let shared = FirestoreService()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Showing Completion
    
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
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Get the current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        // Create a reference to the showing completion document
        let showingCompletionRef = db.collection("users")
            .document(currentUserId)
            .collection("showingCompletions")
            .document(appointmentId)
        
        // Prepare the data to save
        var data: [String: Any] = [
            "appointmentId": appointmentId,
            "propertyAddress": propertyAddress,
            "completionTime": completionTime,
            "clientAttended": clientAttended,
            "feltSafe": feltSafe,
            "followUpNeeded": followUpNeeded,
            "latitude": latitude,
            "longitude": longitude,
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
        
        // Save the data to Firestore
        showingCompletionRef.setData(data) { error in
            if let error = error {
                print("Error saving showing completion: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("Successfully saved showing completion to Firestore")
                
                // Also update the main appointment document to mark it as completed
                self.updateAppointmentStatus(
                    userId: currentUserId,
                    appointmentId: appointmentId,
                    status: "completed",
                    completionTime: completionTime
                ) { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case .failure(let updateError):
                        print("Warning: Completed status update failed: \(updateError.localizedDescription)")
                        // Still return success since we saved the main document
                        completion(.success(()))
                    }
                }
            }
        }
    }
    
    // MARK: - Appointment Management
    
    private func updateAppointmentStatus(
        userId: String,
        appointmentId: String,
        status: String,
        completionTime: Date?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let appointmentRef = db.collection("users")
            .document(userId)
            .collection("appointments")
            .document(appointmentId)
        
        var data: [String: Any] = [
            "status": status,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let completionTime = completionTime {
            data["completionTime"] = completionTime
        }
        
        appointmentRef.updateData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Safety Reports
    
    func reportSafetyIncident(
        appointmentId: String,
        propertyAddress: String,
        details: String,
        latitude: Double,
        longitude: Double,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        // Get user information for the report
        let userRef = db.collection("users").document(currentUserId)
        
        userRef.getDocument { [weak self] (document, error) in
            guard let self = self, error == nil, let document = document, document.exists else {
                let fetchError = error ?? NSError(domain: "FirestoreService", code: 404,
                                               userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                completion(.failure(fetchError))
                return
            }
            
            // Get user data for the report
            let userData = document.data() ?? [:]
            let agentName = userData["name"] as? String ?? "Unknown Agent"
            let agentPhone = userData["phone"] as? String ?? "Unknown Phone"
            
            // Create a safety incident report
            let safetyReportRef = self.db.collection("safetyReports").document()
            
            let reportData: [String: Any] = [
                "reportId": safetyReportRef.documentID,
                "appointmentId": appointmentId,
                "agentId": currentUserId,
                "agentName": agentName,
                "agentPhone": agentPhone,
                "propertyAddress": propertyAddress,
                "details": details,
                "latitude": latitude,
                "longitude": longitude,
                "status": "new",
                "reportedAt": FieldValue.serverTimestamp(),
                "resolved": false
            ]
            
            safetyReportRef.setData(reportData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Office Recap
    
    func sendRecapToOffice(
        appointmentId: String,
        recap: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "FirestoreService", code: 401,
                               userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        // Create a reference to the recap document
        let recapRef = db.collection("officeRecaps").document()
        
        let recapData: [String: Any] = [
            "recapId": recapRef.documentID,
            "appointmentId": appointmentId,
            "agentId": currentUserId,
            "recap": recap,
            "sentAt": FieldValue.serverTimestamp(),
            "read": false
        ]
        
        recapRef.setData(recapData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
} 
