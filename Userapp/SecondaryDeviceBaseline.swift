//
//  SecondaryDeviceBaseline.swift
//  Userapp
//
//  Baseline storage for secondary devices (separate from primary)
//

import Foundation
import RealmSwift

class SecondaryDeviceBaseline: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = "" // Each secondary device has its own baseline
    @Persisted var email: String = ""
    @Persisted var timezone: String = ""
    @Persisted var systemVersion: String = ""
    @Persisted var createdAt: Date = Date()
    
    // Trust history for THIS specific secondary device
    @Persisted var lastTrustScore: Int = 100
    @Persisted var failedAttempts: Int = 0
    @Persisted var successfulVerifications: Int = 0
    
    // ✅ NEW: Decay tracking fields
    @Persisted var lastLoginDate: Date = Date()
    @Persisted var consecutiveActiveDays: Int = 0
    @Persisted var inactiveDayCounter: Int = 0
}
