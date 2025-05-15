import SwiftUI
import Combine
import AuthenticationServices
import CoreLocation
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case welcome, email, location, notifications, profile, contacts, safetyFeatures, mls, finish
}

struct OnboardingFlowView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @AppStorage("onboardingComplete") private var onboardingComplete: Bool = false
    @EnvironmentObject var agent: Agent
    @State private var isSaving = false
    @State private var saveError: String? = nil
    // Add other shared onboarding state as needed

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                switch currentStep {
                case .welcome:
                    AnyView(WelcomeOnboardingView(onContinue: { currentStep = .email }))
                case .email:
                    AnyView(EmailOnboardingView(onContinue: { currentStep = .location }))
                case .location:
                    AnyView(LocationOnboardingView(onContinue: { currentStep = .notifications }))
                case .notifications:
                    AnyView(NotificationOnboardingView(onContinue: { currentStep = .profile }))
                case .profile:
                    AnyView(ProfileSetupOnboardingView(agent: agent, onContinue: { currentStep = .contacts }))
                case .contacts:
                    AnyView(EmergencyContactsOnboardingView(agent: agent, onContinue: { currentStep = .safetyFeatures }))
                case .safetyFeatures:
                    AnyView(SafetyFeaturesOnboardingView(onContinue: { currentStep = .mls }))
                case .mls:
                    AnyView(MLSOnboardingView(onContinue: { currentStep = .finish }))
                case .finish:
                    AnyView(FinishOnboardingView(onDone: {
                        // Save profile to Firestore
                        isSaving = true
                        FirestoreService.shared.updateUserProfile(
                            name: "\(agent.firstName) \(agent.lastName)",
                            email: agent.email,
                            phone: agent.phoneNumber,
                            agentLicense: agent.licenseNumber,
                            officeId: nil,
                            additionalData: nil
                        ) { result in
                            DispatchQueue.main.async {
                                isSaving = false
                                switch result {
                                case .success:
                                    onboardingComplete = true
                                case .failure(let error):
                                    saveError = error.localizedDescription
                                }
                            }
                        }
                    }, isSaving: $isSaving, saveError: $saveError))
                }
                ProgressView(value: Double(currentStep.rawValue), total: Double(OnboardingStep.allCases.count - 1))
                    .padding()
            }
            .animation(.easeInOut, value: currentStep)
        }
    }
}

// MARK: - Placeholder/Example Step Views

struct WelcomeOnboardingView: View {
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to SafeAgent!")
                .font(.largeTitle).bold()
            Text("Your all-in-one safety and compliance app for real estate professionals.")
                .multilineTextAlignment(.center)
            Button("Get Started", action: onContinue)
                .buttonStyle(.borderedProminent)
        }.padding()
    }
}

struct EmailOnboardingView: View {
    let onContinue: () -> Void
    @State private var email = ""
    @State private var error: String?
    @EnvironmentObject var agent: Agent

    var body: some View {
        VStack(spacing: 24) {
            Text("Link your email for notifications and account recovery.")
                .font(.title2)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
            if let error = error {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            Button("Continue") {
                if isValidEmail(email) {
                    agent.email = email
                    onContinue()
                } else {
                    error = "Please enter a valid email address."
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty)
        }.padding()
    }

    private func isValidEmail(_ email: String) -> Bool {
        // Simple regex for email validation
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format:"SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
}

struct ProfileSetupOnboardingView: View {
    @ObservedObject var agent: Agent
    let onContinue: () -> Void
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var pin = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Set up your profile")
                .font(.title2).bold()
            TextField("First Name", text: $firstName)
            TextField("Last Name", text: $lastName)
            TextField("Phone (E.164)", text: $phone)
                .keyboardType(.numberPad)
            SecureField("PIN (4-8 digits)", text: $pin)
                .keyboardType(.numberPad)
            if let error = error {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            Button("Continue") {
                if isValidProfile() {
                    agent.firstName = firstName
                    agent.lastName = lastName
                    agent.phoneNumber = phone
                    agent.pin = pin
                    onContinue()
                } else {
                    error = "Please fill all fields correctly."
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidProfile())
        }.padding()
    }

    private func isValidProfile() -> Bool {
        !firstName.isEmpty && !lastName.isEmpty && phone.count == 11 && phone.hasPrefix("1") && pin.count >= 4 && pin.count <= 8
    }
}

struct EmergencyContactsOnboardingView: View {
    @ObservedObject var agent: Agent
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Emergency Contacts")
                .font(.title2).bold()
            EmergencyContactsView(agent: agent)
                .frame(maxHeight: 300)
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }.padding()
    }
}

struct SafetyFeaturesOnboardingView: View {
    let onContinue: () -> Void
    @AppStorage("featureExcuseCallEnabled") private var excuseCallEnabled: Bool = true
    @AppStorage("featureSiriShortcutEnabled") private var siriShortcutEnabled: Bool = true
    var body: some View {
        VStack(spacing: 16) {
            Text("Safety Features")
                .font(.title2).bold()
            Toggle("Enable Excuse Call", isOn: $excuseCallEnabled)
            Toggle("Enable Siri Shortcut for Panic Alarm", isOn: $siriShortcutEnabled)
            // Add more toggles as needed
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }.padding()
    }
}

struct MLSOnboardingView: View {
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("Link your MLS or Calendar")
                .font(.title2).bold()
            // Add your real MLS/calendar linking UI here
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
        }.padding()
    }
}

struct FinishOnboardingView: View {
    let onDone: () -> Void
    @Binding var isSaving: Bool
    @Binding var saveError: String?
    var body: some View {
        VStack(spacing: 24) {
            Text("You're all set!")
                .font(.largeTitle).bold()
            Text("You can adjust your profile and safety features at any time in the app settings.")
                .multilineTextAlignment(.center)
            if isSaving {
                ProgressView()
            } else if let error = saveError {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            Button("Start Using SafeAgent", action: onDone)
                .buttonStyle(.borderedProminent)
        }.padding()
    }
} 