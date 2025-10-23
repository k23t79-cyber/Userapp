//import Foundation
//import UIKit
//import RealmSwift
//
//// MARK: - Enhanced Device Sync Handler for NEW SCHEMA Bidirectional Updates
//class DeviceSyncHandler {
//    static let shared = DeviceSyncHandler()
//    
//    private var isSubscribed = false
//    private var currentUserId: String?
//    
//    private init() {}
//    
//    // MARK: - Subscription Management (FIXED for userId-based schema)
//    
//    func startSyncing(for userId: String) {
//        guard !isSubscribed || currentUserId != userId else {
//            print("Already subscribed to NEW SCHEMA device sync for userId: \(userId)")
//            return
//        }
//        
//        if currentUserId != userId {
//            stopSyncing()
//        }
//        
//        currentUserId = userId
//        
//        // FIXED: Subscribe using userId instead of email
//        startNewSchemaSubscriptions(userId: userId)
//        
//        isSubscribed = true
//        print("Started NEW SCHEMA bidirectional sync for userId: \(userId)")
//    }
//    
//    func stopSyncing() {
//        guard isSubscribed else { return }
//        
//        SupabaseManager.shared.unsubscribeFromUser()
//        isSubscribed = false
//        currentUserId = nil
//        
//        print("Stopped NEW SCHEMA device sync")
//    }
//    
//    // MARK: - NEW SCHEMA Subscription Setup (FIXED)
//    
//    private func startNewSchemaSubscriptions(userId: String) {
//        // FIXED: Subscribe using userId
//        SupabaseManager.shared.subscribeToUserSummary(userId: userId) { [weak self] summary in
//            self?.handleSummaryUpdate(summary, userId: userId)
//        }
//        
//        SupabaseManager.shared.subscribeToUserHistory(userId: userId) { [weak self] historyEntry in
//            self?.handleHistoryUpdate(historyEntry, userId: userId)
//        }
//        
//        print("NEW SCHEMA subscriptions started for userId: \(userId)")
//    }
//    
//    // MARK: - NEW SCHEMA Update Handlers (FIXED)
//    
//    private func handleSummaryUpdate(_ summary: DeviceSnapshotSummary, userId: String) {
//        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
//        
//        // FIXED: Use device_id instead of primary_device_id
//        guard summary.device_id != currentDeviceId else {
//            print("Ignoring own device summary update")
//            return
//        }
//        
//        print("Received NEW SCHEMA summary update:")
//        print("   - UserId: \(userId)")
//        print("   - Device: \(String(summary.device_id.prefix(8)))...")
//        print("   - Trust Score: \(summary.trust_score ?? 0)")
//        print("   - Is Primary: \(summary.is_primary)")
//        
//        // Notify the app
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(
//                name: NSNotification.Name("NewSchemaSummaryUpdated"),
//                object: [
//                    "summary": summary,
//                    "userId": userId
//                ]
//            )
//        }
//        
//        // Update local Realm
//        updateLocalRealmFromSummary(summary: summary, userId: userId)
//    }
//    
//    private func handleHistoryUpdate(_ historyEntry: DeviceSnapshotHistory, userId: String) {
//        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
//        
//        guard historyEntry.device_id != currentDeviceId else {
//            print("📡 Ignoring own device history update")
//            return
//        }
//        
//        print("Received NEW SCHEMA history update:")
//        print("   - UserId: \(userId)")
//        print("   - Device: \(String(historyEntry.device_id.prefix(8)))...")
//        print("   - Trust Score: \(historyEntry.trust_score ?? 0)")
//        print("   - Is Primary: \(historyEntry.is_primary)")
//        
//        // Process snapshot data
//        if let snapshotData = historyEntry.getSnapshotDataDict() {
//            print("Processing detailed snapshot data from history")
//            updateLocalRealmFromHistoryData(trustSignals: snapshotData, userId: userId, deviceId: historyEntry.device_id)
//        } else {
//            print("Creating basic update from history entry")
//            createBasicUpdateFromHistory(historyEntry: historyEntry, userId: userId)
//        }
//        
//        // Notify the app
//        DispatchQueue.main.async {
//            NotificationCenter.default.post(
//                name: NSNotification.Name("NewSchemaHistoryUpdated"),
//                object: [
//                    "historyEntry": historyEntry,
//                    "userId": userId
//                ]
//            )
//        }
//    }
//    
//    // MARK: - Local Realm Updates
//    w
//    private func updateLocalRealmFromSummary(summary: DeviceSnapshotSummary, userId: String) {
//        do {
//            let realm = try Realm()
//            
//            if let existingSnapshot = realm.objects(TrustSnapshot.self)
//                .filter("userId == %@", userId)
//                .sorted(byKeyPath: "timestamp", ascending: false)
//                .first {
//                
//                try realm.write {
//                    existingSnapshot.trustLevel = Int(summary.trust_score ?? 50)
//                    existingSnapshot.score = Int(summary.trust_score ?? 50)
//                    existingSnapshot.syncStatusRaw = summary.sync_status ?? "synced"
//                    existingSnapshot.syncedAt = Date()
//                }
//                
//                print("Updated local Realm from summary")
//            }
//        } catch {
//            print("Failed to update Realm from summary: \(error)")
//        }
//    }
//    
//    private func updateLocalRealmFromHistoryData(trustSignals: [String: Any], userId: String, deviceId: String) {
//        print("Updating local Realm with history data")
//        
//        do {
//            let realm = try Realm()
//            
//            if let existingSnapshot = realm.objects(TrustSnapshot.self)
//                .filter("userId == %@", userId)
//                .sorted(byKeyPath: "timestamp", ascending: false)
//                .first {
//                
//                try realm.write {
//                    existingSnapshot.trustLevel = trustSignals["trustLevel"] as? Int ?? existingSnapshot.trustLevel
//                    existingSnapshot.score = trustSignals["score"] as? Int ?? existingSnapshot.score
//                    existingSnapshot.isJailbroken = trustSignals["isJailbroken"] as? Bool ?? existingSnapshot.isJailbroken
//                    existingSnapshot.isVPNEnabled = trustSignals["isVPNEnabled"] as? Bool ?? existingSnapshot.isVPNEnabled
//                    existingSnapshot.timezone = trustSignals["timezone"] as? String ?? existingSnapshot.timezone
//                    existingSnapshot.location = trustSignals["location"] as? String ?? existingSnapshot.location
//                    existingSnapshot.uptimeSeconds = trustSignals["uptimeSeconds"] as? Int ?? existingSnapshot.uptimeSeconds
//                    
//                    if let timestampDouble = trustSignals["timestamp"] as? Double {
//                        existingSnapshot.timestamp = Date(timeIntervalSince1970: timestampDouble)
//                    }
//                    
//                    if let flagsString = trustSignals["flags"] as? String {
//                        existingSnapshot.flags = flagsString
//                    }
//                    
//                    existingSnapshot.syncStatusRaw = "synced"
//                    existingSnapshot.syncedAt = Date()
//                }
//                
//                print("Local Realm updated with history data")
//            } else {
//                // Create new snapshot from history data
//                try realm.write {
//                    let newSnapshot = createTrustSnapshotFromNewSchemaData(
//                        trustSignals: trustSignals,
//                        userId: userId,
//                        deviceId: deviceId
//                    )
//                    realm.add(newSnapshot)
//                }
//                
//                print("New Realm snapshot created from history data")
//            }
//        } catch {
//            print("Failed to update Realm from history: \(error)")
//        }
//    }
//    
//    private func createBasicUpdateFromHistory(historyEntry: DeviceSnapshotHistory, userId: String) {
//        let basicTrustSignals: [String: Any] = [
//            "userId": userId,
//            "deviceId": historyEntry.device_id,
//            "trustLevel": Int(historyEntry.trust_score ?? 50),
//            "score": Int(historyEntry.trust_score ?? 50),
//            "timestamp": Date().timeIntervalSince1970,
//            "isJailbroken": false,
//            "isVPNEnabled": false,
//            "timezone": TimeZone.current.identifier,
//            "location": "0.0,0.0",
//            "source": "history_entry_basic"
//        ]
//        
//        updateLocalRealmFromHistoryData(
//            trustSignals: basicTrustSignals,
//            userId: userId,
//            deviceId: historyEntry.device_id
//        )
//    }
//    
//    // MARK: - Helper: Create TrustSnapshot
//    
//    private func createTrustSnapshotFromNewSchemaData(
//        trustSignals: [String: Any],
//        userId: String,
//        deviceId: String
//    ) -> TrustSnapshot {
//        let snapshot = TrustSnapshot()
//        
//        snapshot.userId = userId
//        snapshot.deviceId = deviceId
//        snapshot.isJailbroken = trustSignals["isJailbroken"] as? Bool ?? false
//        snapshot.isVPNEnabled = trustSignals["isVPNEnabled"] as? Bool ?? false
//        snapshot.isUserInteracting = trustSignals["isUserInteracting"] as? Bool ?? false
//        snapshot.uptimeSeconds = trustSignals["uptimeSeconds"] as? Int ?? 0
//        snapshot.timezone = trustSignals["timezone"] as? String ?? ""
//        snapshot.location = trustSignals["location"] as? String ?? ""
//        snapshot.trustLevel = trustSignals["trustLevel"] as? Int ?? 0
//        snapshot.score = trustSignals["score"] as? Int ?? 0
//        
//        if let timestampDouble = trustSignals["timestamp"] as? Double {
//            snapshot.timestamp = Date(timeIntervalSince1970: timestampDouble)
//        } else {
//            snapshot.timestamp = Date()
//        }
//        
//        if let flagsString = trustSignals["flags"] as? String {
//            snapshot.flags = flagsString
//        }
//        
//        snapshot.syncStatusRaw = "synced"
//        snapshot.syncedAt = Date()
//        
//        return snapshot
//    }
//    
//    // MARK: - Status Methods
//    
//    func getSyncStatus() -> String {
//        let subscriptionStatus = isSubscribed ? "Active" : "Inactive"
//        let userInfo = currentUserId ?? "None"
//        
//        return """
//        NEW SCHEMA Device Sync Status:
//        
//        Subscription: \(subscriptionStatus)
//        User ID: \(userInfo)
//        
//        Subscriptions:
//        • Summary Table: \(isSubscribed ? "Active" : "Inactive")
//        • History Table: \(isSubscribed ? "Active" : "Inactive")
//        
//        Architecture: NEW SCHEMA (Summary + History)
//        """
//    }
//    
//    func isCurrentlySubscribed() -> Bool {
//        return isSubscribed
//    }
//    
//    func getCurrentUserId() -> String? {
//        return currentUserId
//    }
//}
//
//// MARK: - Notification Extensions
//
//extension Notification.Name {
//    static let newSchemaSummaryUpdated = Notification.Name("NewSchemaSummaryUpdated")
//    static let newSchemaHistoryUpdated = Notification.Name("NewSchemaHistoryUpdated")
//}
