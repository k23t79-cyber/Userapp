import Foundation
import CoreLocation

/// A lightweight struct (not persisted) used for in-memory cluster calculations.
struct LocationCluster {
    var center: CLLocation
    var visitCount: Int
    var totalDuration: TimeInterval
}
