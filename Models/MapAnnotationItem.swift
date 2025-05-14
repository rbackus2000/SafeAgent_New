import Foundation
import CoreLocation
import MapKit

// This is a shared data structure for map annotations across the app
public struct MapAnnotationItem: Identifiable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    
    public init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
} 