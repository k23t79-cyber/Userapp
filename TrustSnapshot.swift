import Foundation
import RealmSwift

// MARK: - Trust Snapshot Realm Model
class TrustSnapshot: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var isJailbroken: Bool = false
    @Persisted var isVPNEnabled: Bool = false
    @Persisted var isUserInteracting: Bool = false
    @Persisted var uptimeSeconds: Int = 0
    @Persisted var timezone: String = ""
    @Persisted var timestamp: Date = Date()
    @Persisted var location: String = ""      // "lat,lon"
    @Persisted var trustLevel: Int = 0
    @Persisted var score: Int = 0
    @Persisted var flags: String? = nil       // For storing trust signal flags

    // ✅ Motion fields
    @Persisted var motionStateRaw: String = MotionState.unknown.rawValue
    @Persisted var motionMagnitude: Double = 0.0

    // ✅ NEW: App Attest fields
    @Persisted var appAttestVerified: Bool = false
    @Persisted var appAttestScore: Int = 0
    @Persisted var appAttestRiskLevel: String = "unknown"
    @Persisted var appAttestKeyId: String = ""

    // Sync fields
    @Persisted var syncStatusRaw: String = SyncStatus.pending.rawValue
    @Persisted var syncedAt: Date?

    // Link to the cluster it belongs to
    @Persisted var locationCluster: LocationClusterObject?

    // Computed property for sync status
    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }
    
    // ✅ Computed property for motion state
    var motionState: MotionState {
        get { MotionState(rawValue: motionStateRaw) ?? .unknown }
        set { motionStateRaw = newValue.rawValue }
    }
    
    // MARK: - Helper methods for flags
    
    func hasFlag(_ flag: String) -> Bool {
        return flags?.contains(flag) ?? false
    }
    
    func addFlag(_ flag: String) {
        if let currentFlags = flags {
            if !currentFlags.contains(flag) {
                flags = currentFlags + flag + ","
            }
        } else {
            flags = flag + ","
        }
    }
    
    func removeFlag(_ flag: String) {
        flags = flags?.replacingOccurrences(of: flag + ",", with: "")
    }
    
    func getFlagsArray() -> [String] {
        guard let flags = flags, !flags.isEmpty else { return [] }
        return flags.split(separator: ",").map(String.init)
    }
    
    // MARK: - Dictionary Conversion
    
    /// Convert to dictionary for JSON serialization (Supabase compatibility)
    func toDictionary() -> [String: Any] {
        return [
            "id": id.stringValue,
            "userId": userId,
            "deviceId": deviceId,
            "isJailbroken": isJailbroken,
            "isVPNEnabled": isVPNEnabled,
            "isUserInteracting": isUserInteracting,
            "uptimeSeconds": uptimeSeconds,
            "timezone": timezone,
            "timestamp": timestamp.timeIntervalSince1970,
            "location": location,
            "trustLevel": trustLevel,
            "score": score,
            "syncStatus": syncStatus.rawValue,
            "syncedAt": syncedAt?.timeIntervalSince1970 as Any,
            "flags": flags as Any,
            "motionState": motionStateRaw,
            "motionMagnitude": motionMagnitude,
            // ✅ NEW: App Attest fields
            "appAttestVerified": appAttestVerified,
            "appAttestScore": appAttestScore,
            "appAttestRiskLevel": appAttestRiskLevel,
            "appAttestKeyId": appAttestKeyId
        ]
    }
    
    /// Convert to Codable struct for encryption (thread-safe)
    /// ⚠️ CRITICAL: Extract this data BEFORE async operations
    func toCodableData() -> TrustSnapshotData {
        return TrustSnapshotData(
            id: id.stringValue,
            userId: userId,
            deviceId: deviceId,
            isJailbroken: isJailbroken,
            isVPNEnabled: isVPNEnabled,
            isUserInteracting: isUserInteracting,
            uptimeSeconds: uptimeSeconds,
            timezone: timezone,
            timestamp: timestamp,
            location: location,
            trustLevel: trustLevel,
            score: score,
            syncStatus: syncStatus.rawValue,
            syncedAt: syncedAt,
            flags: flags,
            motionState: motionStateRaw,
            motionMagnitude: motionMagnitude,
            // ✅ NEW: App Attest fields
            appAttestVerified: appAttestVerified,
            appAttestScore: appAttestScore,
            appAttestRiskLevel: appAttestRiskLevel,
            appAttestKeyId: appAttestKeyId
        )
    }
    
    /// Convert to Firebase dictionary format
    func toFirebaseDict() -> [String: Any] {
        return toDictionary()
    }
}

// MARK: - Codable Version for Encryption/Serialization

struct TrustSnapshotData: Codable {
    let id: String
    let userId: String
    let deviceId: String
    let isJailbroken: Bool
    let isVPNEnabled: Bool
    let isUserInteracting: Bool
    let uptimeSeconds: Int
    let timezone: String
    let timestamp: Date
    let location: String
    let trustLevel: Int
    let score: Int
    let syncStatus: String
    let syncedAt: Date?
    let flags: String?
    
    // ✅ Motion fields
    let motionState: String
    let motionMagnitude: Double
    
    // ✅ NEW: App Attest fields
    let appAttestVerified: Bool
    let appAttestScore: Int
    let appAttestRiskLevel: String
    let appAttestKeyId: String
}

// MARK: - Trust Signal Event Model

class TrustSignalEvent: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var eventType: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var timestamp: Date = Date()
    @Persisted var impact: Double = 0.0
    @Persisted var eventDetails: Data?  // For storing complex data as JSON
    
    // Value fields for different data types
    @Persisted var boolValue: Bool = false
    @Persisted var doubleValue: Double = 0.0
    @Persisted var intValue: Int = 0
    
    // Helper method to get details as dictionary
    func getDetailsDict() -> [String: Any]? {
        guard let data = eventDetails else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("Error parsing details: \(error)")
            return nil
        }
    }
    
    // Helper method to set details from dictionary
    func updateEventDetails(_ dict: [String: Any]) {
        do {
            eventDetails = try JSONSerialization.data(withJSONObject: dict)
        } catch {
            print("Error setting details: \(error)")
        }
    }
}
