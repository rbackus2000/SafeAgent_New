import SwiftUI
import CoreData
import CloudKit
import FirebaseCore

@main
struct SafeAgentApp: App {
    let persistenceController = PersistenceController.shared
    let safetyMonitorService = SafetyMonitorService()
    @StateObject var authService = AuthenticationService()
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        // Location permissions are handled in SafetyMonitorService
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(safetyMonitorService)
                .environmentObject(authService)
        }
    }
}

import UserNotifications

import CoreData
import EventKit

struct RootView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var safetyMonitorService: SafetyMonitorService
    @State private var notificationGranted: Bool? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @State private var calendarSyncResult: String? = nil
    
    var body: some View {
        Group {
            if !locationAuthorized {
                LocationOnboardingView()
            } else if notificationGranted == false {
                NotificationOnboardingView()
            } else if authService.isAuthenticated {
                ContentView()
                    .onAppear {
                        MLSListingsViewModel().syncAfterLoginIfNeeded()
                    }
            } else {
                LoginView()
            }
        }
        .onAppear {
            checkNotificationPermission()
            triggerCalendarSyncOnLaunch()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-check location status when app becomes active
            safetyMonitorService.locationStatus = CLLocationManager().authorizationStatus
            safetyMonitorService.promptForAlwaysAuthorizationIfNeeded()
            checkNotificationPermission()
        }
    }

    private func triggerCalendarSyncOnLaunch() {
        // Only sync if calendar access is granted
        let calendarService = CalendarService()
        EKEventStore().requestAccess(to: .event) { granted, _ in
            if granted {
                let range = DateInterval(start: Date(), end: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
                calendarService.fetchShowings(for: range) { events in
                    let result = syncCalendarEventsToCoreData(events: events, context: viewContext)
                    DispatchQueue.main.async {
                        calendarSyncResult = "App launch sync: Imported \(result.imported), updated \(result.updated), deleted \(result.deleted) appointments."
                    }
                }
            }
        }
    }
    
    private var locationAuthorized: Bool {
        let status = safetyMonitorService.locationStatus
        print("SwiftUI sees location status: \(status.rawValue)")
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var safetyMonitorService: SafetyMonitorService
    
    var body: some View {
        TabView {
            AppointmentsView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            CalendarShowingsView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar.badge.clock")
                }
            MLSListingsView()
                .tabItem {
                    Label("MLS", systemImage: "house")
                }
            PanicButtonView()
                .tabItem {
                    Label("Panic", systemImage: "exclamationmark.triangle.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}
