//
//  AttributeBaseline.swift
//  Userapp
//
//  Created by Ri on 10/16/25.
//


//
//  AttributeBaseline.swift
//  Userapp
//
//  Stores behavioral baseline for decay tracking
//

import Foundation
import RealmSwift
import CoreLocation

/// Stores the "normal" behavioral patterns for a user
class AttributeBaseline: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    
    // ═══════════════════════════════════════════
    // Network Baseline
    // ═══════════════════════════════════════════
    @Persisted var normalVPNState: Bool = false
    @Persisted var normalNetworkType: String = "WiFi"
    @Persisted var knownIPRanges = List<String>()  // First 3 octets of known IPs
    
    // ═══════════════════════════════════════════
    // Location Baseline (uses your clustering system)
    // ═══════════════════════════════════════════
    // Locations are managed by LocationClusterObject
    // We just track if location trust changed
    
    // ═══════════════════════════════════════════
    // Timezone Baseline
    // ═══════════════════════════════════════════
    @Persisted var normalTimezone: String = "Asia/Kolkata"
    
    // ═══════════════════════════════════════════
    // Login Pattern Baseline
    // ═══════════════════════════════════════════
    @Persisted var normalLoginHoursStart: Int = 7   // 7 AM
    @Persisted var normalLoginHoursEnd: Int = 23    // 11 PM
    
    // ═══════════════════════════════════════════
    // Metadata
    // ═══════════════════════════════════════════
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    
    // ═══════════════════════════════════════════
    // Helper Methods
    // ═══════════════════════════════════════════
    
    /// Check if IP is in known ranges
    func isKnownIP(_ ip: String) -> Bool {
        let ipPrefix = String(ip.prefix(7))  // e.g., "192.168"
        return knownIPRanges.contains { $0 == ipPrefix }
    }
    
    /// Add new IP range if not exists
    func addIPRange(_ ip: String) {
        let ipPrefix = String(ip.prefix(7))
        if !knownIPRanges.contains(ipPrefix) {
            knownIPRanges.append(ipPrefix)
        }
    }
}