//
//  SecondaryDeviceSnapshot.swift
//  Userapp
//
//  Snapshot storage for secondary devices (separate from primary)
//

import Foundation
import RealmSwift

class SecondaryDeviceSnapshot: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var userId: String
    @Persisted var deviceId: String
    @Persisted var timestamp: Date
    @Persisted var trustLevel: Int
    @Persisted var score: Int
    @Persisted var flags: String
    
    // Security signals
    @Persisted var isJailbroken: Bool
    @Persisted var isVPNEnabled: Bool
    @Persisted var isUserInteracting: Bool
    
    // Motion data
    @Persisted var motionStateRaw: String
    @Persisted var motionMagnitude: Double
    
    // App Attest data
    @Persisted var appAttestVerified: Bool
    @Persisted var appAttestScore: Int
    @Persisted var appAttestRiskLevel: String
    @Persisted var appAttestKeyId: String
    
    // Device info
    @Persisted var timezone: String
    @Persisted var location: String
    @Persisted var uptimeSeconds: Int
    @Persisted var systemVersion: String
    @Persisted var networkType: String
    
    // Sync status - Using string
    @Persisted var syncStatusRaw: String
    @Persisted var lastSyncAttempt: Date?
    
    // Helper computed property for motion
    var motion: MotionState {
        return MotionState(rawValue: motionStateRaw) ?? .unknown
    }
    
    // Helper method to add flags
    func addFlag(_ flag: String) {
        if flags.isEmpty {
            flags = flag
        } else if !flags.contains(flag) {
            flags += ",\(flag)"
        }
    }
    
    // Initialize with default values
    override init() {
        super.init()
        self.syncStatusRaw = "pending"
        self.flags = ""
        self.timestamp = Date()
        self.trustLevel = 0
        self.score = 0
        self.location = ""
        self.timezone = ""
        self.systemVersion = ""
        self.networkType = ""
        self.motionStateRaw = "unknown"
        self.motionMagnitude = 0.0
        self.uptimeSeconds = 0
        self.appAttestRiskLevel = "unknown"
        self.appAttestKeyId = ""
    }
}
