import Foundation
import RealmSwift

// Point stored inside a cluster
class EmbeddedLocation: EmbeddedObject {
    @Persisted var latitude: Double = 0
    @Persisted var longitude: Double = 0
    @Persisted var timestamp: Date = Date()
}

// A single raw “visit” before clustering (for history/debug)
class LocationVisitObject: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var latitude: Double = 0
    @Persisted var longitude: Double = 0
    /// minutes stayed for this visit record
    @Persisted var duration: Double = 0
    /// how many times we recorded this exact area (rolling)
    @Persisted var visitCount: Int = 1
    @Persisted var lastVisit: Date = Date()
}

// Cluster of nearby locations
class LocationClusterObject: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString

    // 👇 The names your managers expect
    @Persisted var centerLatitude: Double = 0
    @Persisted var centerLongitude: Double = 0
    @Persisted var radius: Double = 700 // meters

    // rollups
    @Persisted var visitCount: Int = 0
    @Persisted var totalDuration: Double = 0 // minutes

    // raw points that formed this cluster
    @Persisted var locations = List<EmbeddedLocation>()

    // housekeeping
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
}
