import Foundation
import RealmSwift
import UIKit
import FirebaseFirestore

class ActionLogger {
    static let shared = ActionLogger()
    private var syncTimer: Timer?
    private var actionListener: ListenerRegistration?
    
    private init() {
        setupBackgroundSync()
    }
    
    // MARK: - Log Action
    
    func logAction(type: String, payload: [String: Any]) {
        guard let user = RealmManager.shared.fetchAllUsers().first else {
            print("❌ ACTION: No user found")
            return
        }
        
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        // Save to local Realm queue on MAIN thread
        Task { @MainActor in
            do {
                let realm = try Realm()
                let action = UserActionQueue(
                    userId: user.userId,
                    deviceId: deviceId,
                    actionType: type,
                    payload: payload
                )
                
                try realm.write {
                    realm.add(action)
                }
                print("✅ ACTION: Logged locally - \(type)")
                
                // Try immediate sync if online (on background thread)
                if NetworkStateManager.shared.isConnected {
                    Task.detached {
                        await self.syncSingleAction(
                            actionId: action.id,
                            userId: user.userId,
                            deviceId: deviceId,
                            actionType: type,
                            payloadJSON: action.payloadJSON
                        )
                    }
                }
                
            } catch {
                print("❌ ACTION: Failed to log - \(error)")
            }
        }
    }
    
    // MARK: - Sync to Firebase
    
    private func syncSingleAction(
        actionId: String,
        userId: String,
        deviceId: String,
        actionType: String,
        payloadJSON: String
    ) async {
        do {
            let firebaseActionId = try await FirebaseManager.shared.pushUserAction(
                userId: userId,
                deviceId: deviceId,
                actionType: actionType,
                payloadJSON: payloadJSON
            )
            
            // Update local record on MAIN thread with NEW Realm instance
            await MainActor.run {
                Task {
                    do {
                        let realm = try Realm()
                        
                        // Find the action by primary key
                        if let action = realm.object(ofType: UserActionQueue.self, forPrimaryKey: actionId) {
                            try realm.write {
                                action.actionId = firebaseActionId
                                action.syncStatus = "SYNCED"
                            }
                            print("✅ ACTION: Synced to Firebase - \(actionType)")
                        }
                    } catch {
                        print("❌ ACTION: Failed to update sync status - \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ ACTION: Sync failed - \(error)")
            
            // Update sync status to failed on MAIN thread
            await MainActor.run {
                Task {
                    do {
                        let realm = try Realm()
                        
                        if let action = realm.object(ofType: UserActionQueue.self, forPrimaryKey: actionId) {
                            try realm.write {
                                action.syncStatus = "FAILED"
                            }
                        }
                    } catch {
                        print("❌ ACTION: Failed to mark as failed - \(error)")
                    }
                }
            }
        }
    }
    
    func syncPendingActions() async {
        await MainActor.run {
            Task {
                do {
                    let realm = try await Realm()
                    let pendingActions = realm.objects(UserActionQueue.self)
                        .filter("syncStatus == 'PENDING' OR syncStatus == 'FAILED'")
                        .sorted(byKeyPath: "createdAt", ascending: true)
                    
                    // Create a snapshot of data (thread-safe copy)
                    let actionsData: [(id: String, userId: String, deviceId: String, actionType: String, payloadJSON: String)] = pendingActions.map { action in
                        (
                            id: action.id,
                            userId: action.userId,
                            deviceId: action.deviceId,
                            actionType: action.actionType,
                            payloadJSON: action.payloadJSON
                        )
                    }
                    
                    print("📤 ACTION: Syncing \(actionsData.count) pending actions")
                    
                    // Sync on background thread using data snapshot
                    for actionData in actionsData {
                        await syncSingleAction(
                            actionId: actionData.id,
                            userId: actionData.userId,
                            deviceId: actionData.deviceId,
                            actionType: actionData.actionType,
                            payloadJSON: actionData.payloadJSON
                        )
                        
                        // Small delay between syncs
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    }
                    
                } catch {
                    print("❌ ACTION: Batch sync failed - \(error)")
                }
            }
        }
    }
    
    // MARK: - Fetch from Firebase
    
    func fetchAndStoreActionsFromFirebase(userId: String) async {
        do {
            let actions = try await FirebaseManager.shared.getRecentActions(
                userId: userId,
                limit: 100
            )
            
            print("📥 ACTION: Fetched \(actions.count) actions from Firebase")
            
            // Store in local Realm on MAIN thread
            await MainActor.run {
                Task {
                    do {
                        let realm = try Realm()
                        
                        for firebaseAction in actions {
                            // Check if already exists
                            let existing = realm.objects(UserActionQueue.self)
                                .filter("actionId == %@", firebaseAction.id)
                                .first
                            
                            if existing == nil {
                                // Create new local record
                                let localAction = UserActionQueue()
                                localAction.actionId = firebaseAction.id
                                localAction.userId = firebaseAction.user_id
                                localAction.deviceId = firebaseAction.device_id
                                localAction.actionType = firebaseAction.type
                                localAction.payloadJSON = firebaseAction.payload
                                localAction.syncStatus = "SYNCED"
                                localAction.createdAt = Date(timeIntervalSince1970: firebaseAction.created_at)
                                
                                try realm.write {
                                    realm.add(localAction)
                                }
                            }
                        }
                        
                        print("✅ ACTION: Stored Firebase actions locally")
                    } catch {
                        print("❌ ACTION: Failed to store actions - \(error)")
                    }
                }
            }
            
        } catch {
            print("❌ ACTION: Failed to fetch from Firebase - \(error)")
        }
    }
    
    // MARK: - Real-time Listening
    
    func startListeningForActions(userId: String) {
        print("🔔 ACTION: Starting Firebase listener")
        
        actionListener?.remove()
        
        actionListener = FirebaseManager.shared.listenToUserActions(userId: userId) { [weak self] (action: FirebaseUserAction) in
            self?.handleIncomingAction(action)
        }
    }
    
    private func handleIncomingAction(_ action: FirebaseUserAction) {
        print("🔔 ACTION: Received action from other device - \(action.type)")
        
        // Store in local Realm on MAIN thread
        Task { @MainActor in
            do {
                let realm = try Realm()
                
                // Check if already exists
                let existing = realm.objects(UserActionQueue.self)
                    .filter("actionId == %@", action.id)
                    .first
                
                if existing == nil {
                    let localAction = UserActionQueue()
                    localAction.actionId = action.id
                    localAction.userId = action.user_id
                    localAction.deviceId = action.device_id
                    localAction.actionType = action.type
                    localAction.payloadJSON = action.payload
                    localAction.syncStatus = "SYNCED"
                    localAction.createdAt = Date(timeIntervalSince1970: action.created_at)
                    
                    try realm.write {
                        realm.add(localAction)
                    }
                    
                    // Post notification for UI update
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NewActionFromOtherDevice"),
                            object: action
                        )
                    }
                }
                
            } catch {
                print("❌ ACTION: Failed to store incoming action - \(error)")
            }
        }
    }
    
    func stopListening() {
        actionListener?.remove()
        actionListener = nil
        print("🛑 ACTION: Stopped Firebase listener")
    }
    
    // MARK: - Background Sync
    
    private func setupBackgroundSync() {
        // Sync every 30 seconds if there are pending actions
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                if NetworkStateManager.shared.isConnected {
                    await self.syncPendingActions()
                }
            }
        }
        
        // Listen for network recovery
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkRecovered),
            name: .networkRecovered,
            object: nil
        )
    }
    
    @objc private func networkRecovered() {
        print("📡 ACTION: Network recovered, syncing pending actions")
        Task {
            await syncPendingActions()
        }
    }
    
    // MARK: - Stats
    
    func getQueueStats() async -> (total: Int, pending: Int, synced: Int, failed: Int) {
        await MainActor.run {
            guard let realm = try? Realm() else {
                return (0, 0, 0, 0)
            }
            
            let all = realm.objects(UserActionQueue.self)
            let pending = all.filter("syncStatus == 'PENDING'").count
            let synced = all.filter("syncStatus == 'SYNCED'").count
            let failed = all.filter("syncStatus == 'FAILED'").count
            
            return (all.count, pending, synced, failed)
        }
    }
    
    func getRecentActions(limit: Int = 50) async -> [UserActionQueue] {
        await MainActor.run {
            guard let realm = try? Realm() else {
                return []
            }
            
            // Create thread-safe copies
            let results = realm.objects(UserActionQueue.self)
                .sorted(byKeyPath: "createdAt", ascending: false)
                .prefix(limit)
            
            // Detach from Realm for thread-safe usage
            return Array(results).map { action in
                let copy = UserActionQueue()
                copy.id = action.id
                copy.actionId = action.actionId
                copy.userId = action.userId
                copy.deviceId = action.deviceId
                copy.actionType = action.actionType
                copy.payloadJSON = action.payloadJSON
                copy.syncStatus = action.syncStatus
                copy.createdAt = action.createdAt
                return copy
            }
        }
    }
    
    // MARK: - Cleanup
    
    func clearOldActions(olderThan days: Int = 7) async {
        await MainActor.run {
            Task {
                guard let realm = try? Realm() else { return }
                
                let cutoffDate = Date().addingTimeInterval(-Double(days * 24 * 60 * 60))
                let oldActions = realm.objects(UserActionQueue.self)
                    .filter("createdAt < %@ AND syncStatus == 'SYNCED'", cutoffDate)
                
                let count = oldActions.count
                
                try? realm.write {
                    realm.delete(oldActions)
                }
                
                print("🧹 ACTION: Cleaned up \(count) old actions")
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
        actionListener?.remove()
    }
}
