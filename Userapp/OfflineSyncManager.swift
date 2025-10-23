//
//  OfflineSyncManager.swift
//  Userapp
//
//  Created by Ri on 9/12/25.
//

import Foundation
import RealmSwift
import UIKit

// MARK: - Internal Type Definitions (To avoid conflicts)
enum SyncOperationType: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

enum SyncOperationPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low: return "low"
        case .normal: return "normal"
        case .high: return "high"
        case .critical: return "critical"
        }
    }
}

enum SyncOperationStatus: String, CaseIterable {
    case pending = "pending"
    case syncing = "syncing"
    case completed = "completed"
    case failed = "failed"
}

struct SyncCodableSnapshot: Codable {
    let id: String
    let userId: String
    let deviceId: String
    let isJailbroken: Bool
    let isVPNEnabled: Bool
    let isUserInteracting: Bool
    let uptimeSeconds: Int
    let timezone: String
    let timestamp: Date
    let location: String
    let trustLevel: Int
    let score: Int
    let syncStatus: String
    let syncedAt: Date?
}

extension Realm {
    static func createSyncRealm() throws -> Realm {
        let config = Realm.Configuration.defaultConfiguration
        return try Realm(configuration: config)
    }
}

class OfflineSyncManager {
    static let shared = OfflineSyncManager()
    
    private let maxRetryAttempts = 5
    private let maxQueueSize = 100
    private var isSyncing = false
    
    private init() {
        setupNetworkObservers()
    }
    
    // MARK: - Setup
    
    private func setupNetworkObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkRecovered),
            name: .networkRecovered,
            object: nil
        )
    }
    
    @objc private func networkRecovered() {
        DispatchQueue.main.async {
            Task.detached {
                await self.processOfflineQueue()
            }
        }
    }
    
    // MARK: - NEW SCHEMA Queue Operations (THREAD-SAFE)
    
    /// Queue snapshot operation for new schema (Summary + History)
    func queueNewSchemaSnapshotOperation(
        email: String,
        userId: String,
        trustSnapshot: TrustSnapshot,
        operationType: SyncOperationType,
        priority: SyncOperationPriority = .normal
    ) {
        print("📋 Queuing NEW SCHEMA snapshot operation")
        print("📊 Email: \(email), Priority: \(priority.description)")
        
        Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                try realm.write {
                    // Create NEW SCHEMA operation
                    let operation = QueuedNewSchemaOperation()
                    operation.email = email
                    operation.userId = userId
                    operation.deviceId = UIDevice.current.deviceIdentifier
                    operation.operationTypeEnum = operationType
                    operation.priorityEnum = priority
                    operation.setTrustSnapshot(trustSnapshot)
                    operation.syncStatusEnum = .pending
                    operation.trustScore = Double(trustSnapshot.trustLevel)
                    operation.schemaType = "new" // Mark as new schema
                    
                    realm.add(operation)
                    print("✅ NEW SCHEMA operation queued successfully")
                    print("📊 Queue ID: \(operation.operationId)")
                    
                    // Clean up queue if too large
                    self.cleanupNewSchemaQueueIfNeeded(realm: realm)
                }
            } catch {
                print("❌ Failed to queue NEW SCHEMA operation: \(error)")
            }
        }
    }
    
    // MARK: - User Snapshot Queue Operations (THREAD-SAFE)
    
    func queueUserSnapshotOperation(
        email: String,
        userId: String,
        trustSnapshot: TrustSnapshot,
        operationType: SyncOperationType = .update,
        priority: SyncOperationPriority = .normal
    ) {
        print("📋 Queuing user snapshot operation for email: \(email)")
        
        Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                try realm.write {
                    let operation = QueuedUserSnapshotOperation()
                    operation.email = email
                    operation.userId = userId
                    operation.deviceId = UIDevice.current.deviceIdentifier
                    operation.operationTypeEnum = operationType
                    operation.priorityEnum = priority
                    operation.setTrustSnapshot(trustSnapshot)
                    operation.syncStatusEnum = .pending
                    
                    realm.add(operation)
                    print("✅ User snapshot operation queued successfully")
                    
                    // Clean up queue if too large
                    self.cleanupUserQueueIfNeeded(realm: realm)
                }
            } catch {
                print("❌ Failed to queue user snapshot operation: \(error)")
            }
        }
    }
    
    // MARK: - Legacy Device Queue Operations (THREAD-SAFE)
    
    func queueOperation(
        userId: String,
        trustSnapshot: TrustSnapshot,
        operationType: SyncOperationType = .update,
        priority: SyncOperationPriority = .normal
    ) {
        print("📋 Queuing legacy device operation: \(operationType.rawValue) with priority \(priority.description)")
        
        Task { @MainActor in
            // Get user email from Realm for legacy support
            guard let userEmail = await self.getUserEmailFromRealm(userId: userId) else {
                print("❌ Cannot queue legacy operation - user email not found")
                return
            }
            
            // Use the NEW SCHEMA system
            self.queueNewSchemaSnapshotOperation(
                email: userEmail,
                userId: userId,
                trustSnapshot: trustSnapshot,
                operationType: operationType,
                priority: priority
            )
        }
    }
    
    private func getUserEmailFromRealm(userId: String) async -> String? {
        return await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                return realm.objects(UserModel.self)
                    .filter("userId == %@", userId)
                    .first?.email
            } catch {
                print("❌ Error getting user email: \(error)")
                return nil
            }
        }.value
    }
    
    // MARK: - Queue Cleanup Methods (THREAD-SAFE)
    
    private func cleanupNewSchemaQueueIfNeeded(realm: Realm) {
        let queueCount = realm.objects(QueuedNewSchemaOperation.self).count
        
        if queueCount > maxQueueSize {
            print("🧹 NEW SCHEMA queue cleanup needed - current size: \(queueCount)")
            
            // Remove completed operations first
            let completedOps = realm.objects(QueuedNewSchemaOperation.self)
                .filter("syncStatus == 'completed'")
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            if completedOps.count > 10 {
                let toDelete = Array(completedOps.prefix(completedOps.count - 10))
                realm.delete(toDelete)
                print("🧹 Removed \(toDelete.count) completed NEW SCHEMA operations")
            }
            
            // Remove old failed operations
            let oldFailedOps = realm.objects(QueuedNewSchemaOperation.self)
                .filter("syncStatus == 'failed' AND retryCount >= %@", maxRetryAttempts)
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            if oldFailedOps.count > 0 {
                let toDelete = Array(oldFailedOps.prefix(20))
                realm.delete(toDelete)
                print("🧹 Removed \(toDelete.count) old failed NEW SCHEMA operations")
            }
        }
    }
    
    private func cleanupUserQueueIfNeeded(realm: Realm) {
        let queueCount = realm.objects(QueuedUserSnapshotOperation.self).count
        
        if queueCount > maxQueueSize {
            print("🧹 User queue cleanup needed - current size: \(queueCount)")
            
            // Remove completed operations first
            let completedOps = realm.objects(QueuedUserSnapshotOperation.self)
                .filter("syncStatus == 'completed'")
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            if completedOps.count > 10 {
                let toDelete = Array(completedOps.prefix(completedOps.count - 10))
                realm.delete(toDelete)
                print("🧹 Removed \(toDelete.count) completed user operations")
            }
            
            // Remove old failed operations
            let oldFailedOps = realm.objects(QueuedUserSnapshotOperation.self)
                .filter("syncStatus == 'failed' AND retryCount >= %@", maxRetryAttempts)
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            if oldFailedOps.count > 0 {
                let toDelete = Array(oldFailedOps.prefix(20))
                realm.delete(toDelete)
                print("🧹 Removed \(toDelete.count) old failed user operations")
            }
        }
    }
    
    // MARK: - Queue Processing (THREAD-SAFE)
    
    func processOfflineQueue() async {
        guard NetworkStateManager.shared.isConnected else {
            print("📋 Cannot process queue - offline")
            return
        }
        
        guard !isSyncing else {
            print("📋 Sync already in progress")
            return
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("📋 Processing offline queue...")
        
        let (newSchemaOperationIds, userOperationIds, legacyOperationIds) = await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                // Process NEW SCHEMA operations first (highest priority)
                let pendingNewSchemaOps = realm.objects(QueuedNewSchemaOperation.self)
                    .filter("syncStatus == 'pending' OR (syncStatus == 'failed' AND retryCount < %@)", maxRetryAttempts)
                    .sorted(by: [
                        SortDescriptor(keyPath: "priority", ascending: true),
                        SortDescriptor(keyPath: "createdAt", ascending: true)
                    ])
                
                print("📋 Found \(pendingNewSchemaOps.count) NEW SCHEMA operations to sync")
                let newSchemaIds = Array(pendingNewSchemaOps.map { $0.operationId })
                
                // Process user-based operations
                let pendingUserOps = realm.objects(QueuedUserSnapshotOperation.self)
                    .filter("syncStatus == 'pending' OR (syncStatus == 'failed' AND retryCount < %@)", maxRetryAttempts)
                    .sorted(by: [
                        SortDescriptor(keyPath: "priority", ascending: true),
                        SortDescriptor(keyPath: "createdAt", ascending: true)
                    ])
                
                print("📋 Found \(pendingUserOps.count) user snapshot operations to sync")
                let userIds = Array(pendingUserOps.map { $0.operationId })
                
                // Process legacy device operations
                let pendingDeviceOps = realm.objects(QueuedSyncOperation.self)
                    .filter("syncStatus == 'pending' OR (syncStatus == 'failed' AND retryCount < %@)", maxRetryAttempts)
                    .sorted(by: [
                        SortDescriptor(keyPath: "priority", ascending: true),
                        SortDescriptor(keyPath: "createdAt", ascending: true)
                    ])
                
                if pendingDeviceOps.count > 0 {
                    print("📋 Found \(pendingDeviceOps.count) legacy device operations to sync")
                }
                let legacyIds = Array(pendingDeviceOps.map { $0.operationId })
                
                return (newSchemaIds, userIds, legacyIds)
            } catch {
                print("❌ Failed to get pending operations: \(error)")
                return ([], [], [])
            }
        }.value
        
        // Process NEW SCHEMA operations
        for operationId in newSchemaOperationIds {
            await processNewSchemaOperationById(operationId)
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
            } catch {
                break
            }
        }
        
        // Process user operations
        for operationId in userOperationIds {
            await processUserSnapshotOperationById(operationId)
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
        
        // Process legacy operations
        for operationId in legacyOperationIds {
            await processLegacyOperationById(operationId)
            
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                break
            }
        }
        
        // Final count
        let remainingCount = await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                let remainingNewSchema = realm.objects(QueuedNewSchemaOperation.self)
                    .filter("syncStatus == 'pending'").count
                let remainingUser = realm.objects(QueuedUserSnapshotOperation.self)
                    .filter("syncStatus == 'pending'").count
                let remainingLegacy = realm.objects(QueuedSyncOperation.self)
                    .filter("syncStatus == 'pending'").count
                
                return remainingNewSchema + remainingUser + remainingLegacy
            } catch {
                return 0
            }
        }.value
        
        print("📋 Queue processing complete. Remaining pending: \(remainingCount)")
    }
    
    // MARK: - NEW SCHEMA Operation Processing (THREAD-SAFE)
    
    private func processNewSchemaOperationById(_ operationId: String) async {
        print("📋 Processing NEW SCHEMA operation: \(operationId)")
        
        let operationData = await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                guard let operation = realm.object(ofType: QueuedNewSchemaOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find NEW SCHEMA operation: \(operationId)")
                    return (email: "", userId: "", deviceId: "", trustScore: 0.0, trustSnapshot: Optional<TrustSnapshot>.none)
                }
                
                return (
                    email: operation.email,
                    userId: operation.userId,
                    deviceId: operation.deviceId,
                    trustScore: operation.trustScore,
                    trustSnapshot: operation.getTrustSnapshot()
                )
            } catch {
                print("❌ Error accessing NEW SCHEMA operation: \(error)")
                return (email: "", userId: "", deviceId: "", trustScore: 0.0, trustSnapshot: Optional<TrustSnapshot>.none)
            }
        }.value
        
        guard !operationData.email.isEmpty,
              let trustSnapshot = operationData.trustSnapshot else {
            await updateNewSchemaOperationStatus(operationId: operationId, status: SyncOperationStatus.failed, error: "Invalid operation data")
            return
        }
        
        await updateNewSchemaOperationStatus(operationId: operationId, status: SyncOperationStatus.syncing)
        
        print("📊 NEW SCHEMA sync details:")
        print("   - Email: \(operationData.email)")
        print("   - Device: \(String(operationData.deviceId.prefix(8)))...")
        print("   - Trust Score: \(operationData.trustScore)")
        
        do {
            // Upload using NEW SCHEMA method (Summary + History)
//            try await SupabaseManager.shared.upsertUserSnapshot(
//                email: operationData.email,
//                userId: operationData.userId,
//                updatingDeviceId: operationData.deviceId,
//                trustScore: operationData.trustScore,
//                trustSnapshot: trustSnapshot
//            )
            
            await updateNewSchemaOperationStatus(operationId: operationId, status: SyncOperationStatus.completed)
            print("✅ NEW SCHEMA operation synced successfully: \(operationId)")
            print("📊 Summary table updated + History entry added")
            
        } catch {
            print("❌ Failed to sync NEW SCHEMA operation: \(operationId) - \(error)")
            await incrementNewSchemaRetryCount(operationId: operationId, error: error.localizedDescription)
        }
    }
    
    private func processUserSnapshotOperationById(_ operationId: String) async {
        print("📋 Processing user snapshot operation: \(operationId)")
        
        let operationData = await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                guard let operation = realm.object(ofType: QueuedUserSnapshotOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find user operation: \(operationId)")
                    return (email: "", userId: "", deviceId: "", trustSnapshot: Optional<TrustSnapshot>.none)
                }
                
                return (
                    email: operation.email,
                    userId: operation.userId,
                    deviceId: operation.deviceId,
                    trustSnapshot: operation.getTrustSnapshot()
                )
            } catch {
                print("❌ Error accessing user operation: \(error)")
                return (email: "", userId: "", deviceId: "", trustSnapshot: Optional<TrustSnapshot>.none)
            }
        }.value
        
        guard !operationData.email.isEmpty,
              let trustSnapshot = operationData.trustSnapshot else {
            await updateUserOperationStatus(operationId: operationId, status: SyncOperationStatus.failed, error: "Invalid operation data")
            return
        }
        
        await updateUserOperationStatus(operationId: operationId, status: SyncOperationStatus.syncing)
        
        do {
            // Upload to Supabase using the user-based method
//            try await SupabaseManager.shared.upsertUserSnapshot(
//                email: operationData.email,
//                userId: operationData.userId,
//                updatingDeviceId: operationData.deviceId,
//                trustScore: Double(trustSnapshot.trustLevel),
//                trustSnapshot: trustSnapshot
//            )
            
            await updateUserOperationStatus(operationId: operationId, status: SyncOperationStatus.completed)
            print("✅ User snapshot operation synced successfully: \(operationId)")
            
        } catch {
            print("❌ Failed to sync user snapshot operation: \(operationId) - \(error)")
            await incrementUserRetryCount(operationId: operationId, error: error.localizedDescription)
        }
    }
    
    private func processLegacyOperationById(_ operationId: String) async {
        print("📋 Processing legacy device operation: \(operationId)")
        
        let operationData = await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                guard let operation = realm.object(ofType: QueuedSyncOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find legacy operation: \(operationId)")
                    return (userId: "", deviceId: "", email: "", trustSnapshot: Optional<TrustSnapshot>.none)
                }
                
                // Get user email for the userId
                let email = realm.objects(UserModel.self)
                    .filter("userId == %@", operation.userId)
                    .first?.email ?? ""
                
                return (
                    userId: operation.userId,
                    deviceId: operation.deviceId,
                    email: email,
                    trustSnapshot: operation.getTrustSnapshot()
                )
            } catch {
                print("❌ Error accessing legacy operation: \(error)")
                return (userId: "", deviceId: "", email: "", trustSnapshot: Optional<TrustSnapshot>.none)
            }
        }.value
        
        guard !operationData.userId.isEmpty,
              !operationData.email.isEmpty,
              let trustSnapshot = operationData.trustSnapshot else {
            await updateLegacyOperationStatus(operationId: operationId, status: SyncOperationStatus.failed, error: "Invalid operation data or missing email")
            return
        }
        
        await updateLegacyOperationStatus(operationId: operationId, status: SyncOperationStatus.syncing)
        
        do {
            // Convert legacy operation to use the current upsertUserSnapshot method
//            try await SupabaseManager.shared.upsertUserSnapshot(
//                email: operationData.email,
//                userId: operationData.userId,
//                updatingDeviceId: operationData.deviceId,
//                trustScore: Double(trustSnapshot.trustLevel),
//                trustSnapshot: trustSnapshot
//            )
//            
            await updateLegacyOperationStatus(operationId: operationId, status: SyncOperationStatus.completed)
            print("✅ Legacy operation synced successfully: \(operationId)")
            
        } catch {
            print("❌ Failed to sync legacy operation: \(operationId) - \(error)")
            await incrementLegacyRetryCount(operationId: operationId, error: error.localizedDescription)
        }
    }
    
    // MARK: - NEW SCHEMA Operation Status Updates (THREAD-SAFE)
    
    private func updateNewSchemaOperationStatus(
        operationId: String,
        status: SyncOperationStatus,
        error: String? = nil
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.object(ofType: QueuedNewSchemaOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find NEW SCHEMA operation to update: \(operationId)")
                    return
                }
                
                try realm.write {
                    operation.syncStatusEnum = status
                    if let error = error {
                        operation.errorMessage = error
                    }
                }
            } catch {
                print("❌ Failed to update NEW SCHEMA operation status: \(error)")
            }
        }.value
    }
    
    private func incrementNewSchemaRetryCount(operationId: String, error: String) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.object(ofType: QueuedNewSchemaOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find NEW SCHEMA operation to retry: \(operationId)")
                    return
                }
                
                try realm.write {
                    operation.retryCount += 1
                    operation.lastRetryAt = Date()
                    operation.errorMessage = error
                    
                    if operation.retryCount >= maxRetryAttempts {
                        operation.syncStatusEnum = SyncOperationStatus.failed
                        print("❌ NEW SCHEMA operation failed permanently after \(maxRetryAttempts) attempts")
                    } else {
                        operation.syncStatusEnum = SyncOperationStatus.pending
                        print("🔄 Will retry NEW SCHEMA operation. Attempt \(operation.retryCount)/\(maxRetryAttempts)")
                    }
                }
            } catch {
                print("❌ Failed to increment NEW SCHEMA retry count: \(error)")
            }
        }.value
    }
    
    // MARK: - User Operation Status Updates (THREAD-SAFE)
    
    private func updateUserOperationStatus(
        operationId: String,
        status: SyncOperationStatus,
        error: String? = nil
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.object(ofType: QueuedUserSnapshotOperation.self, forPrimaryKey: operationId) else {
                    print("❌ Could not find user operation to update: \(operationId)")
                    return
                }
                
                try realm.write {
                    operation.syncStatusEnum = status
                    if let error = error {
                        operation.errorMessage = error
                    }
                }
            } catch {
                print("❌ Failed to update user operation status: \(error)")
            }
        }.value
    }
    
    private func incrementUserRetryCount(operationId: String, error: String) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.objects(QueuedUserSnapshotOperation.self).filter("operationId == %@", operationId).first else {
                    print("❌ Could not find user operation to retry: \(operationId)")
                    return
                }
                
                try realm.write {
                    operation.retryCount += 1
                    operation.lastRetryAt = Date()
                    operation.errorMessage = error
                    
                    if operation.retryCount >= maxRetryAttempts {
                        operation.syncStatusEnum = SyncOperationStatus.failed
                        print("❌ User operation failed permanently after \(maxRetryAttempts) attempts")
                    } else {
                        operation.syncStatusEnum = SyncOperationStatus.pending
                        print("🔄 Will retry user operation. Attempt \(operation.retryCount)/\(maxRetryAttempts)")
                    }
                }
            } catch {
                print("❌ Failed to increment user retry count: \(error)")
            }
        }.value
    }
    
    // MARK: - Legacy Operation Status Updates (THREAD-SAFE)
    
    private func updateLegacyOperationStatus(
        operationId: String,
        status: SyncOperationStatus,
        error: String? = nil
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.objects(QueuedSyncOperation.self).filter("operationId == %@", operationId).first else {
                    print("❌ Could not find legacy operation to update: \(operationId)")
                    return
                }
                
                try realm.write {
                    // Convert SyncOperationStatus to the legacy SyncStatus type
                    let legacyStatus = convertToLegacySyncStatus(status)
                    operation.syncStatusEnum = legacyStatus
                    if let error = error {
                        operation.errorMessage = error
                    }
                }
            } catch {
                print("❌ Failed to update legacy operation status: \(error)")
            }
        }.value
    }
    
    private func incrementLegacyRetryCount(operationId: String, error: String) async {
        await Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                guard let operation = realm.objects(QueuedSyncOperation.self).filter("operationId == %@", operationId).first else {
                    print("❌ Could not find legacy operation to retry: \(operationId)")
                    return
                }
                
                try realm.write {
                    operation.retryCount += 1
                    operation.lastRetryAt = Date()
                    operation.errorMessage = error
                    
                    if operation.retryCount >= maxRetryAttempts {
                        let legacyFailedStatus = convertToLegacySyncStatus(.failed)
                        operation.syncStatusEnum = legacyFailedStatus
                        print("❌ Legacy operation failed permanently after \(maxRetryAttempts) attempts")
                    } else {
                        let legacyPendingStatus = convertToLegacySyncStatus(.pending)
                        operation.syncStatusEnum = legacyPendingStatus
                        print("🔄 Will retry legacy operation. Attempt \(operation.retryCount)/\(maxRetryAttempts)")
                    }
                }
            } catch {
                print("❌ Failed to increment legacy retry count: \(error)")
            }
        }.value
    }
    
    // MARK: - Helper Methods for Type Conversion
    
    /// Convert SyncOperationStatus to legacy SyncStatus enum
    private func convertToLegacySyncStatus(_ status: SyncOperationStatus) -> SyncStatus {
        switch status {
        case .pending:
            return SyncStatus(rawValue: "pending") ?? .pending
        case .syncing:
            return SyncStatus(rawValue: "syncing") ?? .pending
        case .completed:
            return SyncStatus(rawValue: "completed") ?? .pending
        case .failed:
            return SyncStatus(rawValue: "failed") ?? .pending
        }
    }
    
    // MARK: - Queue Information (THREAD-SAFE)
    
    func getQueueStatus() -> (pending: Int, syncing: Int, completed: Int, failed: Int) {
        let result = Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                // NEW SCHEMA operations
                let newSchemaPending = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'pending'").count
                let newSchemaSyncing = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'syncing'").count
                let newSchemaCompleted = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'completed'").count
                let newSchemaFailed = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'failed'").count
                
                // User-based operations
                let userPending = realm.objects(QueuedUserSnapshotOperation.self).filter("syncStatus == 'pending'").count
                let userSyncing = realm.objects(QueuedUserSnapshotOperation.self).filter("syncStatus == 'syncing'").count
                let userCompleted = realm.objects(QueuedUserSnapshotOperation.self).filter("syncStatus == 'completed'").count
                let userFailed = realm.objects(QueuedUserSnapshotOperation.self).filter("syncStatus == 'failed'").count
                
                // Legacy device operations
                let legacyPending = realm.objects(QueuedSyncOperation.self).filter("syncStatus == 'pending'").count
                let legacySyncing = realm.objects(QueuedSyncOperation.self).filter("syncStatus == 'syncing'").count
                let legacyCompleted = realm.objects(QueuedSyncOperation.self).filter("syncStatus == 'completed'").count
                let legacyFailed = realm.objects(QueuedSyncOperation.self).filter("syncStatus == 'failed'").count
                
                return (
                    pending: newSchemaPending + userPending + legacyPending,
                    syncing: newSchemaSyncing + userSyncing + legacySyncing,
                    completed: newSchemaCompleted + userCompleted + legacyCompleted,
                    failed: newSchemaFailed + userFailed + legacyFailed
                )
            } catch {
                print("❌ Failed to get queue status: \(error)")
                return (pending: 0, syncing: 0, completed: 0, failed: 0)
            }
        }
        
        // Wait for the result synchronously (this is safe for status queries)
        return runBlocking { await result.value }
    }
    
    func getNewSchemaQueueStatus() -> (pending: Int, syncing: Int, completed: Int, failed: Int) {
        let result = Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                let pending = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'pending'").count
                let syncing = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'syncing'").count
                let completed = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'completed'").count
                let failed = realm.objects(QueuedNewSchemaOperation.self).filter("syncStatus == 'failed'").count
                
                return (pending: pending, syncing: syncing, completed: completed, failed: failed)
            } catch {
                print("❌ Failed to get NEW SCHEMA queue status: \(error)")
                return (pending: 0, syncing: 0, completed: 0, failed: 0)
            }
        }
        
        return runBlocking { await result.value }
    }
    
    func clearCompletedOperations() {
        Task { @MainActor in
            do {
                let realm = try Realm.createSyncRealm()
                
                // Clear NEW SCHEMA completed operations
                let completedNewSchemaOps = realm.objects(QueuedNewSchemaOperation.self)
                    .filter("syncStatus == 'completed'")
                
                // Clear user-based completed operations
                let completedUserOps = realm.objects(QueuedUserSnapshotOperation.self)
                    .filter("syncStatus == 'completed'")
                
                // Clear legacy completed operations
                let completedLegacyOps = realm.objects(QueuedSyncOperation.self)
                    .filter("syncStatus == 'completed'")
                
                try realm.write {
                    realm.delete(completedNewSchemaOps)
                    realm.delete(completedUserOps)
                    realm.delete(completedLegacyOps)
                }
                
                let totalCleared = completedNewSchemaOps.count + completedUserOps.count + completedLegacyOps.count
                print("🧹 Cleared \(totalCleared) completed operations")
            } catch {
                print("❌ Failed to clear completed operations: \(error)")
            }
        }
    }
    
    func getNewSchemaOperationsSummary() -> String {
        let status = getNewSchemaQueueStatus()
        let networkStatus = NetworkStateManager.shared.isConnected ? "Online" : "Offline"
        
        return """
        📊 NEW SCHEMA Queue Status:
        
        Network: \(networkStatus)
        
        Operations:
        • Pending: \(status.pending)
        • Syncing: \(status.syncing) 
        • Completed: \(status.completed)
        • Failed: \(status.failed)
        
        Architecture:
        • Summary Table: device_snapshots
        • History Table: device_snapshots_history
        
        Each operation:
        1. Updates summary table (one row per user)
        2. Adds history entry (full snapshot data)
        """
    }
    
    // MARK: - Manual Triggers
    
    func forceSyncAll() {
        Task.detached {
            await self.processOfflineQueue()
        }
    }
    
    func forceSyncNewSchemaOperations() {
        print("🚀 Force syncing all pending NEW SCHEMA operations...")
        
        guard NetworkStateManager.shared.isConnected else {
            print("❌ Cannot force sync - device is offline")
            return
        }
        
        Task.detached {
            await self.processOfflineQueue()
        }
    }
    
    // MARK: - Helper Methods
    
    private func runBlocking<T>(_ task: @escaping () async -> T) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T!
        
        Task {
            result = await task()
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NEW SCHEMA Realm Model

class QueuedNewSchemaOperation: Object {
    @Persisted var operationId: String = UUID().uuidString
    @Persisted var email: String = ""
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var operationType: String = ""
    @Persisted var priority: Int = 0
    @Persisted var syncStatus: String = ""
    @Persisted var trustSnapshotData: String = ""
    @Persisted var trustScore: Double = 0.0
    @Persisted var schemaType: String = "new" // Always "new" for new schema
    @Persisted var retryCount: Int = 0
    @Persisted var errorMessage: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var lastRetryAt: Date?
    
    override static func primaryKey() -> String? {
        return "operationId"
    }
    
    var operationTypeEnum: SyncOperationType {
        get { SyncOperationType(rawValue: operationType) ?? .update }
        set { operationType = newValue.rawValue }
    }
    
    var priorityEnum: SyncOperationPriority {
        get { SyncOperationPriority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
    
    var syncStatusEnum: SyncOperationStatus {
        get { SyncOperationStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
    
    func setTrustSnapshot(_ snapshot: TrustSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(SyncCodableSnapshot(
                id: snapshot.id.stringValue,
                userId: snapshot.userId,
                deviceId: snapshot.deviceId,
                isJailbroken: snapshot.isJailbroken,
                isVPNEnabled: snapshot.isVPNEnabled,
                isUserInteracting: snapshot.isUserInteracting,
                uptimeSeconds: snapshot.uptimeSeconds,
                timezone: snapshot.timezone,
                timestamp: snapshot.timestamp,
                location: snapshot.location,
                trustLevel: snapshot.trustLevel,
                score: snapshot.score,
                syncStatus: snapshot.syncStatusRaw,
                syncedAt: snapshot.syncedAt
            ))
            trustSnapshotData = String(data: data, encoding: .utf8) ?? ""
            trustScore = Double(snapshot.trustLevel) // Store trust score separately
        } catch {
            print("❌ Failed to encode NEW SCHEMA trust snapshot: \(error)")
        }
    }
    
    func getTrustSnapshot() -> TrustSnapshot? {
        guard !trustSnapshotData.isEmpty,
              let data = trustSnapshotData.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let codableSnapshot = try decoder.decode(SyncCodableSnapshot.self, from: data)
            
            // Convert back to TrustSnapshot
            // Create TrustSnapshot with basic properties first
            // We cannot set @Persisted properties directly outside of a Realm write transaction
            let trustSnapshot = TrustSnapshot()
            trustSnapshot.userId = codableSnapshot.userId
            trustSnapshot.deviceId = codableSnapshot.deviceId
            trustSnapshot.isJailbroken = codableSnapshot.isJailbroken
            trustSnapshot.isVPNEnabled = codableSnapshot.isVPNEnabled
            trustSnapshot.isUserInteracting = codableSnapshot.isUserInteracting
            trustSnapshot.uptimeSeconds = codableSnapshot.uptimeSeconds
            trustSnapshot.timezone = codableSnapshot.timezone
            trustSnapshot.timestamp = codableSnapshot.timestamp
            trustSnapshot.location = codableSnapshot.location
            trustSnapshot.trustLevel = codableSnapshot.trustLevel
            trustSnapshot.score = codableSnapshot.score
            trustSnapshot.syncedAt = codableSnapshot.syncedAt
            
            // Note: syncStatusRaw will be set when this snapshot is added to Realm
            // For now, it will use the default value from the TrustSnapshot model
            
            return trustSnapshot
        } catch {
            print("❌ Failed to decode NEW SCHEMA trust snapshot: \(error)")
            return nil
        }
    }
}

// MARK: - User Snapshot Realm Model

class QueuedUserSnapshotOperation: Object {
    @Persisted var operationId: String = UUID().uuidString
    @Persisted var email: String = ""
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var operationType: String = ""
    @Persisted var priority: Int = 0
    @Persisted var syncStatus: String = ""
    @Persisted var trustSnapshotData: String = ""
    @Persisted var retryCount: Int = 0
    @Persisted var errorMessage: String = ""
    @Persisted var createdAt: Date = Date()
    @Persisted var lastRetryAt: Date?
    
    override static func primaryKey() -> String? {
        return "operationId"
    }
    
    var operationTypeEnum: SyncOperationType {
        get { SyncOperationType(rawValue: operationType) ?? .update }
        set { operationType = newValue.rawValue }
    }
    
    var priorityEnum: SyncOperationPriority {
        get { SyncOperationPriority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
    
    var syncStatusEnum: SyncOperationStatus {
        get { SyncOperationStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
    
    func setTrustSnapshot(_ snapshot: TrustSnapshot) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(SyncCodableSnapshot(
                id: snapshot.id.stringValue,
                userId: snapshot.userId,
                deviceId: snapshot.deviceId,
                isJailbroken: snapshot.isJailbroken,
                isVPNEnabled: snapshot.isVPNEnabled,
                isUserInteracting: snapshot.isUserInteracting,
                uptimeSeconds: snapshot.uptimeSeconds,
                timezone: snapshot.timezone,
                timestamp: snapshot.timestamp,
                location: snapshot.location,
                trustLevel: snapshot.trustLevel,
                score: snapshot.score,
                syncStatus: snapshot.syncStatusRaw,
                syncedAt: snapshot.syncedAt
            ))
            trustSnapshotData = String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Failed to encode trust snapshot: \(error)")
        }
    }
    
    func getTrustSnapshot() -> TrustSnapshot? {
        guard !trustSnapshotData.isEmpty,
              let data = trustSnapshotData.data(using: .utf8) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let codableSnapshot = try decoder.decode(SyncCodableSnapshot.self, from: data)
            
            // Convert back to TrustSnapshot
            let trustSnapshot = TrustSnapshot()
            trustSnapshot.userId = codableSnapshot.userId
            trustSnapshot.deviceId = codableSnapshot.deviceId
            trustSnapshot.isJailbroken = codableSnapshot.isJailbroken
            trustSnapshot.isVPNEnabled = codableSnapshot.isVPNEnabled
            trustSnapshot.isUserInteracting = codableSnapshot.isUserInteracting
            trustSnapshot.uptimeSeconds = codableSnapshot.uptimeSeconds
            trustSnapshot.timezone = codableSnapshot.timezone
            trustSnapshot.timestamp = codableSnapshot.timestamp
            trustSnapshot.location = codableSnapshot.location
            trustSnapshot.trustLevel = codableSnapshot.trustLevel
            trustSnapshot.score = codableSnapshot.score
            trustSnapshot.syncedAt = codableSnapshot.syncedAt
            
            // Note: syncStatusRaw will be set when this snapshot is added to Realm
            // For now, it will use the default value from the TrustSnapshot model
            
            return trustSnapshot
        } catch {
            print("❌ Failed to decode trust snapshot: \(error)")
            return nil
        }
    }
}
