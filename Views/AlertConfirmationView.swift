import SwiftUI

struct AlertConfirmationView: View {
    let title: String
    let message: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.title2)
                .bold()
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            HStack(spacing: 32) {
                Button("Cancel", action: cancelAction)
                    .foregroundColor(.secondary)
                Button("Confirm", action: confirmAction)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    AlertConfirmationView(title: "Activate Alarm?", message: "This will notify your contacts and police.", confirmAction: {}, cancelAction: {})
}
