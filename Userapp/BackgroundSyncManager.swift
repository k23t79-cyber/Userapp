//import BackgroundTasks
//import Foundation
//import UIKit
//import UserNotifications
//import RealmSwift
//
//class BackgroundSyncManager {
//    static let shared = BackgroundSyncManager()
//    
//    private let backgroundSyncIdentifier = "com.userapp.trustsync"
//    private let quickSyncIdentifier = "com.userapp.quicksync"
//    
//    private init() {}
//    
//    func registerBackgroundTasks() {
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: backgroundSyncIdentifier,
//            using: nil
//        ) { task in
//            self.handleBackgroundSync(task: task as! BGProcessingTask)
//        }
//        
//        BGTaskScheduler.shared.register(
//            forTaskWithIdentifier: quickSyncIdentifier,
//            using: nil
//        ) { task in
//            self.handleQuickSync(task: task as! BGAppRefreshTask)
//        }
//    }
//    
//    private func handleBackgroundSync(task: BGProcessingTask) {
//        task.expirationHandler = {
//            task.setTaskCompleted(success: false)
//        }
//        
//        Task {
//            await performFullTrustSync()
//            task.setTaskCompleted(success: true)
//            scheduleBackgroundSync()
//        }
//    }
//    
//    private func handleQuickSync(task: BGAppRefreshTask) {
//        task.expirationHandler = {
//            task.setTaskCompleted(success: false)
//        }
//        
//        Task {
//            await performQuickTrustCheck()
//            task.setTaskCompleted(success: true)
//            scheduleQuickSync()
//        }
//    }
//    
//    func scheduleBackgroundSync() {
//        let request = BGProcessingTaskRequest(identifier: backgroundSyncIdentifier)
//        request.requiresNetworkConnectivity = true
//        request.requiresExternalPower = false
//        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
//        
//        try? BGTaskScheduler.shared.submit(request)
//    }
//    
//    func scheduleQuickSync() {
//        let request = BGAppRefreshTaskRequest(identifier: quickSyncIdentifier)
//        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
//        
//        try? BGTaskScheduler.shared.submit(request)
//    }
//    
//    // MARK: - Background Operations (FIXED)
//    
//    private func performFullTrustSync() async {
//        guard NetworkStateManager.shared.isConnected else { return }
//        guard let user = getCurrentUser() else { return }
//        
//        await OfflineSyncManager.shared.processOfflineQueue()
//        
//        do {
//            // FIXED: Use userId instead of email
//            if let userSummary = try await SupabaseManager.shared.getUserSummary(for: user.userId) {
//                let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
//                
//                // FIXED: Use device_id instead of primary_device_id
//                if userSummary.device_id != currentDeviceId {
//                    let historyEntries = try await SupabaseManager.shared.getUserHistory(for: user.userId, limit: 5)
//                    
//                    if let latestEntry = historyEntries.first {
//                        await sendCrossDeviceNotification(
//                            userId: user.userId,
//                            updatingDevice: latestEntry.device_id,
//                            trustScore: Int(latestEntry.trust_score ?? userSummary.trust_score ?? 50)
//                        )
//                        
//                        storeBackgroundUpdate(
//                            summary: userSummary,
//                            latestHistory: latestEntry,
//                            userId: user.userId
//                        )
//                    }
//                }
//            }
//        } catch {
//            print("Background sync error: \(error)")
//        }
//    }
//    
//    private func performQuickTrustCheck() async {
//        let isJailbroken = DeviceSecurityChecker.isJailbroken()
//        let isVPNEnabled = VPNChecker.shared.isVPNConnected()
//        
//        if isJailbroken || isVPNEnabled {
//            await performFullTrustSync()
//        }
//    }
//    
//    // FIXED: Store background update with userId
//    private func storeBackgroundUpdate(
//        summary: DeviceSnapshotSummary,
//        latestHistory: DeviceSnapshotHistory,
//        userId: String
//    ) {
//        UserDefaults.standard.set(true, forKey: "pendingTrustUpdate")
//        UserDefaults.standard.set(Int(summary.trust_score ?? 50), forKey: "pendingTrustScore")
//        UserDefaults.standard.set(summary.device_id, forKey: "pendingUpdatingDevice") // FIXED
//        UserDefaults.standard.set(userId, forKey: "pendingUpdateUserId")
//        UserDefaults.standard.set("new_schema", forKey: "pendingUpdateType")
//        
//        // Update local Realm if snapshot data available
//        if let snapshotDataDict = latestHistory.getSnapshotDataDict() {
//            updateLocalRealmFromRemoteHistory(
//                trustSignals: snapshotDataDict,
//                userId: userId
//            )
//        } else {
//            let basicTrustSignals: [String: Any] = [
//                "userId": userId,
//                "deviceId": summary.device_id, // FIXED
//                "trustLevel": Int(summary.trust_score ?? 50),
//                "timestamp": Date().timeIntervalSince1970,
//                "isJailbroken": false,
//                "isVPNEnabled": false,
//                "timezone": TimeZone.current.identifier,
//                "location": "0.0,0.0"
//            ]
//            
//            updateLocalRealmFromRemoteHistory(
//                trustSignals: basicTrustSignals,
//                userId: userId
//            )
//        }
//    }
//    
//    private func updateLocalRealmFromRemoteHistory(trustSignals: [String: Any], userId: String) {
//        do {
//            let realm = try Realm()
//            
//            let trustSnapshot = TrustSnapshot()
//            trustSnapshot.userId = userId
//            trustSnapshot.deviceId = trustSignals["deviceId"] as? String ?? ""
//            trustSnapshot.isJailbroken = trustSignals["isJailbroken"] as? Bool ?? false
//            trustSnapshot.isVPNEnabled = trustSignals["isVPNEnabled"] as? Bool ?? false
//            trustSnapshot.isUserInteracting = trustSignals["isUserInteracting"] as? Bool ?? false
//            trustSnapshot.uptimeSeconds = trustSignals["uptimeSeconds"] as? Int ?? 0
//            trustSnapshot.timezone = trustSignals["timezone"] as? String ?? ""
//            
//            if let timestampDouble = trustSignals["timestamp"] as? Double {
//                trustSnapshot.timestamp = Date(timeIntervalSince1970: timestampDouble)
//            } else {
//                trustSnapshot.timestamp = Date()
//            }
//            
//            trustSnapshot.location = trustSignals["location"] as? String ?? ""
//            trustSnapshot.trustLevel = trustSignals["trustLevel"] as? Int ?? 0
//            trustSnapshot.score = trustSignals["score"] as? Int ?? trustSnapshot.trustLevel
//            
//            if let flagsString = trustSignals["flags"] as? String {
//                trustSnapshot.flags = flagsString
//            }
//            
//            trustSnapshot.syncStatusRaw = "synced"
//            trustSnapshot.syncedAt = Date()
//            
//            try realm.write {
//                realm.add(trustSnapshot, update: .modified)
//            }
//            
//        } catch {
//            print("Error updating Realm: \(error)")
//        }
//    }
//    
//    private func getCurrentUser() -> UserModel? {
//        do {
//            let realm = try Realm()
//            return realm.objects(UserModel.self).first
//        } catch {
//            return nil
//        }
//    }
//    
//    private func sendCrossDeviceNotification(
//        userId: String,
//        updatingDevice: String,
//        trustScore: Int
//    ) async {
//        let content = UNMutableNotificationContent()
//        content.title = "Security Update"
//        content.body = "Trust score updated to \(trustScore) by device \(String(updatingDevice.prefix(8)))..."
//        content.sound = UNNotificationSound.default
//        
//        content.userInfo = [
//            "userId": userId,
//            "updatingDevice": updatingDevice,
//            "trustScore": trustScore,
//            "updateType": "cross_device",
//            "schema": "new"
//        ]
//        
//        let request = UNNotificationRequest(
//            identifier: "cross_device_update_\(UUID().uuidString)",
//            content: content,
//            trigger: nil
//        )
//        
//        try? await UNUserNotificationCenter.current().add(request)
//    }
//    
//    // MARK: - Manual Triggers
//    
//    func triggerBackgroundSync() {
//        Task {
//            await performFullTrustSync()
//        }
//    }
//    
//    func triggerQuickCheck() {
//        Task {
//            await performQuickTrustCheck()
//        }
//    }
//    
//    // MARK: - Status
//    
//    func getBackgroundSyncStatus() -> String {
//        let networkStatus = NetworkStateManager.shared.isConnected ? "Online" : "Offline"
//        let queueStatus = OfflineSyncManager.shared.getNewSchemaQueueStatus()
//        
//        return """
//        Background Sync Status (NEW SCHEMA):
//        
//        Network: \(networkStatus)
//        
//        Queue Status:
//        • Pending: \(queueStatus.pending)
//        • Syncing: \(queueStatus.syncing)
//        • Failed: \(queueStatus.failed)
//        
//        Background Tasks:
//        • Full Sync: Every 15 minutes
//        • Quick Check: Every 5 minutes
//        """
//    }
//    
//    func clearBackgroundUpdateFlags() {
//        UserDefaults.standard.removeObject(forKey: "pendingTrustUpdate")
//        UserDefaults.standard.removeObject(forKey: "pendingTrustScore")
//        UserDefaults.standard.removeObject(forKey: "pendingUpdatingDevice")
//        UserDefaults.standard.removeObject(forKey: "pendingUpdateUserId")
//        UserDefaults.standard.removeObject(forKey: "pendingUpdateType")
//    }
//    
//    func hasPendingBackgroundUpdate() -> Bool {
//        return UserDefaults.standard.bool(forKey: "pendingTrustUpdate")
//    }
//}
