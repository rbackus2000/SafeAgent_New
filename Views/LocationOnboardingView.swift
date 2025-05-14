import SwiftUI

struct LocationOnboardingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.blue)
            Text("Enable Location Services")
                .font(.title2)
                .bold()
            Text("SafeAgent uses your location to automatically detect when you arrive at a showing and to provide emergency assistance if needed. Please enable location services for the best experience.")
                .multilineTextAlignment(.center)
                .font(.body)
            Button("Open Location Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.headline)
        }
        .padding()
    }
}

#Preview {
    LocationOnboardingView()
}
