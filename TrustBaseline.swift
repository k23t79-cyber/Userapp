//
//  TrustBaseline.swift
//  Userapp
//

import Foundation
import RealmSwift

class TrustBaseline: Object {
    @Persisted(primaryKey: true) var userId: String = ""
    @Persisted var email: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var systemVersion: String = ""
    @Persisted var timezone: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var signalsJSON: Data?
    
    // ═══════════════════════════════════════════
    // Trust Score Tracking (NO TIME-BASED DECAY)
    // ═══════════════════════════════════════════
    @Persisted var lastLoginDate: Date = Date()
    @Persisted var lastTrustScore: Int = 100
    
    // ✅ REMOVED: consecutiveActiveDays (not needed)
    // ✅ REMOVED: inactiveDayCounter (not needed)
    
    // ═══════════════════════════════════════════
    // Link to Attribute Baseline
    // ═══════════════════════════════════════════
    @Persisted var attributeBaseline: AttributeBaseline?
    
    convenience init(userId: String, email: String) {
        self.init()
        self.userId = userId
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastLoginDate = Date()
        self.lastTrustScore = 100
    }
    
    func toDictionary() -> [String: Any]? {
        guard let jsonData = signalsJSON else { return nil }
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    }
}


