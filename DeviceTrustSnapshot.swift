import Foundation
import RealmSwift


class DeviceTrustSnapshot: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var deviceSignature: String
    @Persisted var playIntegrityVerdict: String
    @Persisted var isRooted: Bool
    @Persisted var vpnDetected: Bool
    @Persisted var uptime: Double
    @Persisted var timezone: String
    @Persisted var ipAddress: String
    @Persisted var location: String
    @Persisted var touchInteraction: Bool
    @Persisted var timestamp: Date
    @Persisted var trustScore: Int
}
