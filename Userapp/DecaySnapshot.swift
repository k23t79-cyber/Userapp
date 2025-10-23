//
//  DecaySnapshot.swift
//  Userapp
//
//  Created by Ri on 10/16/25.
//


//
//  DecaySnapshot.swift
//  Userapp
//
//  Stores decay history for behavior tracking
//

import Foundation
import RealmSwift

class DecaySnapshot: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var timestamp: Date = Date()
    
    // ═══════════════════════════════════════════
    // Trust Score Tracking
    // ═══════════════════════════════════════════
    @Persisted var previousScore: Int = 100
    @Persisted var currentScore: Int = 100
    @Persisted var decayAmount: Int = 0  // previousScore - currentScore
    
    // ═══════════════════════════════════════════
    // Decay Breakdown (negative values = decay)
    // ═══════════════════════════════════════════
    @Persisted var locationDecay: Int = 0
    @Persisted var vpnDecay: Int = 0
    @Persisted var networkDecay: Int = 0
    @Persisted var timezoneDecay: Int = 0
    @Persisted var ipDecay: Int = 0
    @Persisted var loginTimeDecay: Int = 0
    @Persisted var jailbreakDecay: Int = 0
    
    // ═══════════════════════════════════════════
    // Metadata
    // ═══════════════════════════════════════════
    @Persisted var severity: String = "None"  // none, minimal, low, medium, high, critical
    
    // ═══════════════════════════════════════════
    // Helper: Get total attribute-based decay
    // ═══════════════════════════════════════════
    var totalAttributeDecay: Int {
        return locationDecay + vpnDecay + networkDecay + timezoneDecay + ipDecay + loginTimeDecay + jailbreakDecay
    }
}
struct DecaySnapshotResult {
    let decayAmount: Int
    let severity: String
    let previousScore: Int
    let currentScore: Int
    let locationDecay: Int
    let vpnDecay: Int
    let networkDecay: Int
    let timezoneDecay: Int
    let ipDecay: Int
    let loginTimeDecay: Int
    let jailbreakDecay: Int
}
