import SwiftUI

struct SafetyDashboardWatchView: View {
    @EnvironmentObject var safetyMonitorService: SafetyMonitorService
    @State private var showPanicAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Safety")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: {
                showPanicAlert = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                    Text("PANIC")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.panicButton)
            .alert(isPresented: $showPanicAlert) {
                Alert(
                    title: Text("Activate Alarm?"),
                    message: Text("Notify contacts and police?"),
                    primaryButton: .destructive(Text("Activate")) {
                        safetyMonitorService.triggerPanicButton()
                    },
                    secondaryButton: .cancel()
                )
            }
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SafetyDashboardWatchView().environmentObject(SafetyMonitorService())
}
