import SwiftUI
import EventKit

import CoreData

struct CalendarShowingsView: View {
    @StateObject var calendarService = CalendarService()
    @State private var calendarAccessGranted = false
    @State private var showings: [EKEvent] = []
    @State private var error: String?
    @State private var isSyncing = false
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack {
            if !calendarAccessGranted {
                CalendarOnboardingView()
                Button("Grant Calendar Access") {
                    calendarService.requestAccess { granted in
                        calendarAccessGranted = granted
                        if !granted { error = "Calendar access denied." }
                    }
                }
                .padding(.top, 24)
            } else {
                if isSyncing {
                    ProgressView("Syncing calendar...")
                        .padding()
                } else if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List(showings, id: \.eventIdentifier) { event in
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .font(.headline)
                            if let loc = event.location {
                                Text(loc)
                                    .font(.subheadline)
                            }
                            Text(event.startDate, style: .date)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            calendarService.requestAccess { granted in
                calendarAccessGranted = granted
                if granted {
                    isSyncing = true
                    let range = DateInterval(start: Date(), end: Calendar.current.date(byAdding: .day, value: 7, to: Date())!)
                    calendarService.fetchShowings(for: range) { events in
                        showings = events
                        isSyncing = false
                        if events.isEmpty {
                            error = "No showings found for this week."
                        } else {
                            error = nil
                        }
                    }
                } else {
                    error = "Calendar access denied."
                }
            }
        }
    }
}

#Preview {
    CalendarShowingsView()
}
