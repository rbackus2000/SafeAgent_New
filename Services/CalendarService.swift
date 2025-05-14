import Foundation
import EventKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var showings: [EKEvent] = []
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func fetchShowings(for dateRange: DateInterval, completion: @escaping ([EKEvent]) -> Void) {
        let predicate = eventStore.predicateForEvents(withStart: dateRange.start, end: dateRange.end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        let keywords = ["showing", "tour"]
        let filteredEvents = events.filter { event in
            let lowerTitle = event.title?.lowercased() ?? ""
            let lowerLocation = event.location?.lowercased() ?? ""
            return keywords.contains(where: { lowerTitle.contains($0) || lowerLocation.contains($0) })
        }
        DispatchQueue.main.async {
            completion(filteredEvents)
        }
    }
}
