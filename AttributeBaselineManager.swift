//
//  AttributeBaselineManager.swift
//  Userapp
//
//  Created by Ri on 10/16/25.
//


//
//  AttributeBaselineManager.swift
//  Userapp
//
//  Manages creation and updates of attribute baselines
//

import Foundation
import RealmSwift

class AttributeBaselineManager {
    
    static let shared = AttributeBaselineManager()
    private init() {}
    
    // ═══════════════════════════════════════════
    // Create or Update Baseline
    // ═══════════════════════════════════════════
    
    func createOrUpdateBaseline(
        userId: String,
        deviceId: String,
        signals: TrustSignals
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                
                // Find existing or create new
                var baseline: AttributeBaseline
                if let existing = realm.objects(AttributeBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first {
                    baseline = existing
                } else {
                    baseline = AttributeBaseline()
                    baseline.userId = userId
                    baseline.deviceId = deviceId
                    baseline.createdAt = Date()
                }
                
                try realm.write {
                    // Update VPN baseline (if this is normal behavior)
                    baseline.normalVPNState = signals.isVPNEnabled
                    
                    // Update network baseline
                    baseline.normalNetworkType = signals.networkType
                    
                    // Update IP range
                    baseline.addIPRange(signals.ipAddress)
                    
                    // Update timezone
                    baseline.normalTimezone = signals.timezone
                    
                    // Update login time pattern
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    if baseline.normalLoginHoursStart == 7 && baseline.normalLoginHoursEnd == 23 {
                        // First login - set based on current time
                        baseline.normalLoginHoursStart = max(0, currentHour - 2)
                        baseline.normalLoginHoursEnd = min(23, currentHour + 2)
                    }
                    
                    baseline.updatedAt = Date()
                    
                    realm.add(baseline, update: .modified)
                }
                
                print("✅ Attribute baseline updated for user \(String(userId.prefix(8)))...")
                
            } catch {
                print("❌ Error updating attribute baseline: \(error)")
            }
        }.value
    }
    
    // ═══════════════════════════════════════════
    // Fetch Baseline
    // ═══════════════════════════════════════════
    
    func fetchBaseline(userId: String, deviceId: String) async -> AttributeBaseline? {
        return await Task { @MainActor in
            do {
                let realm = try Realm()
                return realm.objects(AttributeBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first
            } catch {
                print("❌ Error fetching attribute baseline: \(error)")
                return nil
            }
        }.value
    }
    
    // ═══════════════════════════════════════════
    // Link Baseline to TrustBaseline
    // ═══════════════════════════════════════════
    
    func linkToTrustBaseline(
        userId: String,
        deviceId: String,
        trustBaseline: TrustBaseline
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                
                guard let attributeBaseline = realm.objects(AttributeBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first else {
                    print("⚠️  No attribute baseline found to link")
                    return
                }
                
                try realm.write {
                    trustBaseline.attributeBaseline = attributeBaseline
                }
                
                print("✅ Linked attribute baseline to trust baseline")
                
            } catch {
                print("❌ Error linking baselines: \(error)")
            }
        }.value
    }
}