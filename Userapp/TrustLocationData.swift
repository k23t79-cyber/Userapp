import Foundation
import CoreLocation

/// Raw data for trust evaluation.
struct TrustLocationData {
    let location: CLLocation
    let visitCount: Int
    let durationMinutes: Double
}
