import SwiftUI

struct CalendarOnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.blue)
            Text("Connect Your Calendars")
                .font(.title2)
                .bold()
            Text("To see all your appointments, add your Gmail, Outlook, and other accounts to your device’s Calendar (Settings > Calendar > Accounts). SafeAgent will automatically fetch events from all connected calendars.")
                .multilineTextAlignment(.center)
                .font(.body)
            Link("Open Calendar Settings", destination: URL(string: "App-prefs:root=CALENDARS")!)
                .font(.headline)
        }
        .padding()
    }
}

#Preview {
    CalendarOnboardingView()
}
