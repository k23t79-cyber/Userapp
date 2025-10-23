import Foundation
import CoreLocation
import RealmSwift

final class LocationClusterManager {
    static let shared = LocationClusterManager()
    private init() {}
    
    /// Called when saving a new user location.
    func saveOrUpdateCluster(for location: CLLocation, userId: String) {
        do {
            let realm = try Realm()
            
            // 1. Fetch all visits for this user within 700m
            let allVisits = realm.objects(LocationVisit.self).filter("userId == %@", userId)
            
            let nearbyVisits = allVisits.filter { visit in
                let dist = location.distance(from: CLLocation(latitude: visit.latitude, longitude: visit.longitude))
                return dist <= 700
            }
            
            // 2. Calculate cumulative stats
            let totalVisits = nearbyVisits.count
            let totalDuration = nearbyVisits.reduce(0) { $0 + $1.durationMinutes }
            
            // 3. Only create cluster if condition is met
            guard totalVisits >= 3, totalDuration >= 45 else {
                print("⏳ Not enough visits/duration for cluster yet.")
                return
            }
            
            try realm.write {
                // 4. Create new cluster object
                let cluster = LocationClusterObject()
                cluster.centerLatitude = location.coordinate.latitude
                cluster.centerLongitude = location.coordinate.longitude
                cluster.radius = 700
                cluster.visitCount = totalVisits
                cluster.totalDuration = Double(totalDuration)
                
                // Add visits to cluster.locations
                for v in nearbyVisits {
                    let embedded = EmbeddedLocation()
                    embedded.latitude = v.latitude
                    embedded.longitude = v.longitude
                    cluster.locations.append(embedded)
                }
                
                realm.add(cluster, update: .modified)
                
                // 5. Cleanup old visits (optional)
                realm.delete(nearbyVisits)
            }
            
            print("📌 Cluster saved with \(totalVisits) visits and \(totalDuration) mins duration.")
            
        } catch {
            print("❌ Error saving cluster: \(error)")
        }
    }
}
