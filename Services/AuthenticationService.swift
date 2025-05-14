import Foundation
import AuthenticationServices
import SwiftUI
import FirebaseAuth
import CryptoKit
import FirebaseFirestore

class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userIdentifier: String?
    @Published var error: String?
    
    // For Apple Sign In
    private var currentNonce: String?
    
    override init() {
        super.init()
        // Check if user is already signed in
        if let user = Auth.auth().currentUser {
            self.isAuthenticated = true
            self.userIdentifier = user.uid
        }
    }
    
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // Generate a random nonce for the Apple Sign in credential verification
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // Generate a SHA256 hash of the nonce for Apple's verification
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func firebaseSignInWithApple(credential: ASAuthorizationAppleIDCredential) {
        // Verify the nonce
        guard let nonce = currentNonce else {
            print("Invalid state: A login callback was received, but no login request was sent.")
            self.error = "Authentication error: Invalid state"
            return
        }
        
        guard let appleIDToken = credential.identityToken else {
            print("Unable to fetch identity token")
            self.error = "Authentication error: Unable to fetch identity token"
            return
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Unable to serialize token string from data")
            self.error = "Authentication error: Unable to serialize token"
            return
        }
        
        // Create Firebase credential
        let firebaseCredential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        // Sign in with Firebase
        Auth.auth().signIn(with: firebaseCredential) { [weak self] (authResult, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Firebase sign in error: \(error.localizedDescription)")
                self.error = "Sign in failed: \(error.localizedDescription)"
                self.isAuthenticated = false
                return
            }
            
            // User is signed in to Firebase
            if let user = authResult?.user {
                print("Successfully signed in to Firebase with Apple ID: \(user.uid)")
                self.userIdentifier = user.uid
                self.isAuthenticated = true
                
                // Create/update user profile if we have name information
                if let fullName = credential.fullName, 
                   (fullName.givenName != nil || fullName.familyName != nil) {
                    
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    
                    if !displayName.isEmpty {
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        changeRequest.commitChanges { error in
                            if let error = error {
                                print("Error updating display name: \(error.localizedDescription)")
                            }
                        }
                        
                        // Create a basic user document in Firestore
                        self.createBasicUserProfile(userId: user.uid, displayName: displayName, email: credential.email)
                    }
                } else {
                    // Create a basic user document even without name information
                    self.createBasicUserProfile(userId: user.uid, displayName: nil, email: credential.email)
                }
            }
        }
    }
    
    // Helper method to create a basic user profile document in Firestore
    private func createBasicUserProfile(userId: String, displayName: String?, email: String?) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userId)
        
        var userData: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp(),
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        if let displayName = displayName {
            userData["name"] = displayName
        }
        
        if let email = email {
            userData["email"] = email
        }
        
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                print("Error creating basic user profile: \(error.localizedDescription)")
            } else {
                print("Successfully created/updated basic user profile in Firestore")
            }
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Use the Apple ID credential to sign in with Firebase
            firebaseSignInWithApple(credential: appleIDCredential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Sign in with Apple error: \(error.localizedDescription)")
        self.error = "Sign in failed: \(error.localizedDescription)"
        self.isAuthenticated = false
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
