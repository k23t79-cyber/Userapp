//
//  SnapshotMergeManager.swift
//  Userapp
//
//  Created by Ri on 10/9/25.
//


import Foundation
import RealmSwift

class SnapshotMergeManager {
    static let shared = SnapshotMergeManager()
    
    private init() {}
    
    // MARK: - Step 7: Cross-Device Snapshot Merging (Matching Android)
    
    /// Merge secondary device snapshot with primary device data
    func mergeSnapshots(
        primarySnapshot: TrustSnapshot,
        secondarySnapshotData: [String: Any]
    ) -> TrustSnapshot {
        print("🔄 MERGE MANAGER: Merging primary and secondary snapshots")
        
        let mergedSnapshot = TrustSnapshot()
        mergedSnapshot.userId = primarySnapshot.userId
        mergedSnapshot.deviceId = primarySnapshot.deviceId
        
        // Merge security signals (take worst case)
        mergedSnapshot.isJailbroken = primarySnapshot.isJailbroken || (secondarySnapshotData["isJailbroken"] as? Bool ?? false)
        mergedSnapshot.isVPNEnabled = primarySnapshot.isVPNEnabled || (secondarySnapshotData["isVPNEnabled"] as? Bool ?? false)
        
        // Merge behavior signals
        mergedSnapshot.isUserInteracting = primarySnapshot.isUserInteracting
        mergedSnapshot.uptimeSeconds = primarySnapshot.uptimeSeconds
        mergedSnapshot.timezone = primarySnapshot.timezone
        mergedSnapshot.location = primarySnapshot.location
        
        // Recalculate trust level based on merged data
        var mergedScore = 100
        
        if mergedSnapshot.isJailbroken {
            mergedScore -= 30
        }
        if mergedSnapshot.isVPNEnabled {
            mergedScore -= 15
        }
        
        mergedSnapshot.trustLevel = max(0, mergedScore)
        mergedSnapshot.score = mergedScore
        mergedSnapshot.timestamp = Date()
        mergedSnapshot.syncStatusRaw = TrustStatus.merged.rawValue
        
        // Add merge flags
        mergedSnapshot.addFlag("merged_with_secondary")
        mergedSnapshot.addFlag("cross_device_verified")
        
        print("✅ MERGE MANAGER: Merge complete")
        print("   - Merged Trust Score: \(mergedScore)")
        print("   - Jailbroken (any device): \(mergedSnapshot.isJailbroken)")
        print("   - VPN (any device): \(mergedSnapshot.isVPNEnabled)")
        
        return mergedSnapshot
    }
    
    /// Handle incoming secondary device snapshot
    func handleSecondarySnapshot(
        userId: String,
        secondaryDeviceId: String,
        snapshotData: [String: Any]
    ) {
        print("📥 MERGE MANAGER: Received secondary device snapshot")
        print("   - Secondary Device: \(String(secondaryDeviceId.prefix(8)))...")
        
        // Get latest primary snapshot
        guard let primarySnapshot = getLatestPrimarySnapshot(userId: userId) else {
            print("❌ MERGE MANAGER: No primary snapshot found")
            return
        }
        
        // Merge the snapshots
        let mergedSnapshot = mergeSnapshots(
            primarySnapshot: primarySnapshot,
            secondarySnapshotData: snapshotData
        )
        
        // Save merged snapshot to Realm
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(mergedSnapshot, update: .modified)
            }
            print("✅ MERGE MANAGER: Merged snapshot saved to Realm")
            
            // Upload merged snapshot to Firebase
            Task {
                try await FirebaseManager.shared.addPrimaryDeviceSnapshotHistory(
                    userId: userId,
                    deviceId: primarySnapshot.deviceId,
                    isPrimary: true,
                    trustScore: Float(mergedSnapshot.trustLevel),
                    snapshotData: mergedSnapshot.toFirebaseDict()
                )
                print("✅ MERGE MANAGER: Merged snapshot uploaded to Firebase")
            }
            
        } catch {
            print("❌ MERGE MANAGER: Failed to save merged snapshot - \(error)")
        }
    }
    
    private func getLatestPrimarySnapshot(userId: String) -> TrustSnapshot? {
        do {
            let realm = try Realm()
            return realm.objects(TrustSnapshot.self)
                .filter("userId == %@", userId)
                .sorted(byKeyPath: "timestamp", ascending: false)
                .first
        } catch {
            print("❌ Error getting primary snapshot: \(error)")
            return nil
        }
    }
}