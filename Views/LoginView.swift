import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    @State private var showError = false
    
    // Set to false for production
    private let showDebugUI = true
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark ? Color(hex: "121212") : Color(hex: "F5F7FA"),
                    colorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "E4E9F2")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // Content
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and app name
                VStack(spacing: 20) {
                    // Use custom logo or fallback to SF Symbol
                    Group {
                        if UIImage(named: "SafeAgentLogo") != nil {
                            Image("SafeAgentLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            // Fallback to SF Symbol
                            Image(systemName: "shield.checkerboard")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .padding(.bottom, 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .opacity(isAnimating ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Text("SafeAgent")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(isAnimating ? 1.0 : 0.9)
                        .animation(.easeInOut(duration: 1.5).delay(0.2).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // Welcome text
                VStack(spacing: 12) {
                    Text("Welcome to SafeAgent")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your personal safety companion for real estate showings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(isAnimating ? 1.0 : 0.7)
                .animation(.easeIn(duration: 1.0).delay(0.4), value: isAnimating)
                
                Spacer()
                
                // Manual sign in button for testing
                if showDebugUI {
                    Button(action: {
                        authService.signInWithApple()
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                }
                
                // Error message
                if let error = authService.error, showError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                
                // Only show authentication status in debug mode
                if showDebugUI && authService.isAuthenticated {
                    VStack(spacing: 4) {
                        Text("Debug info:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Signed in as: \(authService.userIdentifier ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                
                // Footer text
                Text("Your security is our priority")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: isAnimating)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // Start animations after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isAnimating = true
            }
        }
        .onChange(of: authService.error) { newValue in
            if newValue != nil {
                showError = true
                
                // Hide error after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    showError = false
                }
            }
        }
    }
}

// Color extension to support hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView().environmentObject(AuthenticationService())
}
