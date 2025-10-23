//
//  QueuedSyncOperation.swift
//  Userapp
//
//  Created by Ri on 9/12/25.
//


import Foundation
import RealmSwift

// MARK: - Offline Queue Models

class QueuedSyncOperation: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var operationId: String = UUID().uuidString
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var operationType: String = "update" // create, update, delete
    @Persisted var priority: Int = 1 // 1=critical, 2=high, 3=normal
    @Persisted var trustSnapshotData: Data? // Serialized TrustSnapshot
    @Persisted var createdAt: Date = Date()
    @Persisted var syncStatus: String = "pending" // pending, syncing, completed, failed
    @Persisted var retryCount: Int = 0
    @Persisted var lastRetryAt: Date?
    @Persisted var errorMessage: String?
    
    // Computed properties
    var operationTypeEnum: OperationType {
        get { OperationType(rawValue: operationType) ?? .update }
        set { operationType = newValue.rawValue }
    }
    
    var priorityEnum: OperationPriority {
        get { OperationPriority(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }
    
    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
    
    // Helper methods
    func getTrustSnapshot() -> TrustSnapshot? {
        guard let data = trustSnapshotData else { return nil }
        
        do {
            let decoder = JSONDecoder()
            let snapshotDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return createTrustSnapshotFromDict(snapshotDict ?? [:])
        } catch {
            print("❌ Failed to deserialize trust snapshot: \(error)")
            return nil
        }
    }
    
    func setTrustSnapshot(_ snapshot: TrustSnapshot) {
        do {
            let snapshotDict = snapshot.toDictionary()
            trustSnapshotData = try JSONSerialization.data(withJSONObject: snapshotDict)
        } catch {
            print("❌ Failed to serialize trust snapshot: \(error)")
        }
    }
    
    private func createTrustSnapshotFromDict(_ dict: [String: Any]) -> TrustSnapshot {
        let snapshot = TrustSnapshot()
        
        snapshot.userId = dict["userId"] as? String ?? ""
        snapshot.deviceId = dict["deviceId"] as? String ?? ""
        snapshot.isJailbroken = dict["isJailbroken"] as? Bool ?? false
        snapshot.isVPNEnabled = dict["isVPNEnabled"] as? Bool ?? false
        snapshot.trustLevel = dict["trustLevel"] as? Int ?? 0
        snapshot.score = dict["score"] as? Int ?? 0
        snapshot.timezone = dict["timezone"] as? String ?? ""
        snapshot.location = dict["location"] as? String ?? "0.0,0.0"
        
        if let timestamp = dict["timestamp"] as? Double {
            snapshot.timestamp = Date(timeIntervalSince1970: timestamp)
        }
        
        return snapshot
    }
}

// MARK: - Enums

enum OperationType: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

enum OperationPriority: Int, CaseIterable {
    case critical = 1    // Security events (jailbreak detected, etc.)
    case high = 2       // Trust score changes
    case normal = 3     // General updates
    
    var description: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .normal: return "Normal"
        }
    }
}

enum SyncStatus: String, CaseIterable {
    case pending = "pending"
    case syncing = "syncing" 
    case completed = "completed"
    case failed = "failed"
    
    var description: String {
        switch self {
        case .pending: return "Pending"
        case .syncing: return "Syncing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}