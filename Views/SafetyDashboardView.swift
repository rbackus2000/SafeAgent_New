import SwiftUI

struct SafetyDashboardView: View {
    @EnvironmentObject var safetyMonitorService: SafetyMonitorService
    @State private var showPanicAlert = false
    
    private var locationStatusText: String {
        switch safetyMonitorService.locationStatus {
        case .authorizedAlways: return "Location access: Always"
        case .authorizedWhenInUse: return "Location access: When In Use"
        case .denied: return "Location access: Denied"
        case .restricted: return "Location access: Restricted"
        case .notDetermined: return "Location access: Not Determined"
        @unknown default: return "Location access: Unknown"
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Safety Dashboard")
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 20)
            
            Spacer()
            
            Button(action: {
                showPanicAlert = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 120, height: 120)
                        .shadow(radius: 10)
                    Text("PANIC")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                        .accessibilityLabel("Panic Button. Double tap to alert emergency contacts and police.")
                }
            }
            .accessibilityIdentifier("panicButton")
            .alert(isPresented: $showPanicAlert) {
                Alert(
                    title: Text("Activate Emergency Alarm?"),
                    message: Text("This will notify your emergency contacts and local authorities."),
                    primaryButton: .destructive(Text("Activate")) {
                        safetyMonitorService.triggerPanicButton()
                    },
                    secondaryButton: .cancel()
                )
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "location")
                    if let loc = safetyMonitorService.currentLocation {
                        Text("Current Location: \(loc.latitude, specifier: "%.4f"), \(loc.longitude, specifier: "%.4f")")
                            .font(.footnote)
                            .accessibilityLabel("Current Location Coordinates")
                    } else {
                        Text("Location Unavailable")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.gray)
                    Text(locationStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                if let error = safetyMonitorService.locationError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .padding()
        .navigationTitle("Safety")
    }
}

#Preview {
    SafetyDashboardView()
        .environmentObject(SafetyMonitorService())
}
