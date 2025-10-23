import Foundation
import CoreLocation
import RealmSwift

final class TrustManager {
    static let shared = TrustManager()
    private init() {}

    /// Evaluate trust based on clusters.
    func evaluateLocationTrust(currentLocation: CLLocation) -> Bool {
        do {
            let realm = try Realm()
            let clusters = realm.objects(LocationClusterObject.self)

            for cluster in clusters {
                let clusterLoc = CLLocation(latitude: cluster.centerLatitude,
                                            longitude: cluster.centerLongitude)
                let distance = currentLocation.distance(from: clusterLoc)

                // Trusted if inside 700m of a cluster with â‰¥3 visits & â‰¥45 mins total duration
                if distance <= cluster.radius &&
                    cluster.visitCount >= 3 &&
                    cluster.totalDuration >= 45 {
                    return true
                }
            }
        } catch {
            print("âŒ Realm error in evaluateLocationTrust: \(error.localizedDescription)")
        }
        return false
    }
}
