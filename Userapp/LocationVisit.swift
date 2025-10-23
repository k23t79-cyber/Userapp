import Foundation
import RealmSwift
import CoreLocation

class LocationVisit: Object {
    @Persisted(primaryKey: true) var id: ObjectId

    @Persisted var userId: String = ""
    @Persisted var latitude: Double = 0.0
    @Persisted var longitude: Double = 0.0

    @Persisted var arrivalDate: Date = Date()
    @Persisted var departureDate: Date? = nil

    @Persisted var visitCount: Int = 0

    /// ✅ Persisted cumulative duration across all visits (minutes)
    @Persisted var totalDurationMinutes: Int = 0

    /// ✅ Backwards-compatibility alias (not persisted)
    /// Any code that still uses `durationMinutes` will now compile
    var durationMinutes: Int {
        get { totalDurationMinutes }
        set { totalDurationMinutes = newValue }
    }

    // Convenience
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Call when ending a session to add this session’s minutes to the total
    func updateDuration() {
        guard let departure = departureDate else { return }
        let minutes = max(Int(departure.timeIntervalSince(arrivalDate) / 60), 0)
        totalDurationMinutes += minutes
    }
}
