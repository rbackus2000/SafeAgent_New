import SwiftUI

struct NotificationOnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.badge.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.blue)
            Text("Enable Notifications")
                .font(.title2)
                .bold()
            Text("SafeAgent uses notifications to alert you in case of emergencies and to keep you updated on your appointments. Please enable notifications to stay informed and safe.")
                .multilineTextAlignment(.center)
                .font(.body)
            Link("Open Notification Settings", destination: URL(string: "App-prefs:root=NOTIFICATIONS_ID")!)
                .font(.headline)
        }
        .padding()
    }
}

#Preview {
    NotificationOnboardingView()
}
