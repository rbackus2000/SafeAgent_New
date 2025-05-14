import Foundation
import CoreLocation
import EventKit

struct AppointmentModel: Identifiable, Codable {
    let id: UUID
    let title: String
    let propertyAddress: String
    let startTime: Date
    let endTime: Date
    var location: CLLocationCoordinate2D?
    var status: AppointmentStatus
    var mlsListingId: String?
    
    enum AppointmentStatus: String, Codable {
        case scheduled
        case inProgress
        case completed
        case cancelled
    }
    
    static func fromEKEvent(_ event: EKEvent) -> AppointmentModel? {
        guard let location = event.structuredLocation?.geoLocation else { return nil }
        
        return AppointmentModel(
            id: UUID(),
            title: event.title ?? "Untitled Showing",
            propertyAddress: event.structuredLocation?.title ?? "",
            startTime: event.startDate,
            endTime: event.endDate,
            location: CLLocationCoordinate2D(
                latitude: location.coordinate.latitude, 
                longitude: location.coordinate.longitude
            ),
            status: .scheduled,
            mlsListingId: nil
        )
    }
}

extension AppointmentModel {
    enum CodingKeys: String, CodingKey {
        case id, title, propertyAddress, startTime, endTime, location, status, mlsListingId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        propertyAddress = try container.decode(String.self, forKey: .propertyAddress)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        if let loc = try container.decodeIfPresent([Double].self, forKey: .location), loc.count == 2 {
            location = CLLocationCoordinate2D(latitude: loc[0], longitude: loc[1])
        } else {
            location = nil
        }
        status = try container.decode(AppointmentStatus.self, forKey: .status)
        mlsListingId = try container.decodeIfPresent(String.self, forKey: .mlsListingId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(propertyAddress, forKey: .propertyAddress)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        if let loc = location {
            try container.encode([loc.latitude, loc.longitude], forKey: .location)
        }
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(mlsListingId, forKey: .mlsListingId)
    }
}
