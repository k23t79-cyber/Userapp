import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import RealmSwift
import CryptoKit

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    private init() {}
    
    // MARK: - SECONDARY DEVICE - device_snapshots collection
    // This stores which secondary device is currently syncing with the primary
    // MARK: - Store Secondary Device Snapshot in device_snapshots_history

    /// Store SECONDARY device snapshot in device_snapshots_history collection
    func storeSecondaryDeviceSnapshot(
        userId: String,
        deviceId: String,
        trustScore: Float,
        snapshotData: [String: Any]
    ) async throws {
        
        print("🔵 FIREBASE: Storing SECONDARY device snapshot")
        print("   👤 UserId: \(userId)")
        print("   📱 Device: \(String(deviceId.prefix(8)))...")
        print("   📊 Trust Score: \(trustScore)")
        
        // Convert snapshotData to JSON string (with Date conversion)
        let cleanedSnapshotData = convertDatesToTimestamps(snapshotData)
        let jsonData = try JSONSerialization.data(withJSONObject: cleanedSnapshotData)
        let snapshotDataString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let historyData: [String: Any] = [
            "userId": userId,
            "deviceId": deviceId,
            "isPrimary": false,  // ✅ Always FALSE for secondary devices
            "trustScore": trustScore,
            "syncStatus": "synced",
            "snapshotData": snapshotDataString,  // ✅ Full snapshot as JSON string
            "createdAt": timestamp
        ]
        
        // ✅ Store in device_snapshots_history with auto-generated ID
        // ✅ Store in nested structure: device_snapshots_history/{userId}/devices/{deviceId}
        try await db.collection("device_snapshots_history")
            .document(userId)           // User document
            .collection("devices")      // Devices subcollection
            .document(deviceId)         // Device document
            .setData(historyData, merge: true)
        
        print("✅ FIREBASE: SECONDARY device snapshot stored")
        print("   📂 Collection: device_snapshots_history")
        print("   📄 Document: Auto-generated ID")
    }

    // MARK: - Helper: Convert Dates to Timestamps

    private func convertDatesToTimestamps(_ data: Any) -> Any {
        // Handle Date objects
        if let date = data as? Date {
            return date.timeIntervalSince1970
        }
        
        // Handle NSDate objects
        if let nsDate = data as? NSDate {
            return nsDate.timeIntervalSince1970
        }
        
        // Handle dictionaries recursively
        if let dict = data as? [String: Any] {
            return dict.mapValues { convertDatesToTimestamps($0) }
        }
        
        // Handle arrays recursively
        if let array = data as? [Any] {
            return array.map { convertDatesToTimestamps($0) }
        }
        
        return data
    }
    
    
    
    
    
    func upsertSecondaryDeviceSnapshot(
        userId: String,
        primaryDeviceId: String,
        trustScore: Float
    ) async throws {
        
        print("🔵 FIREBASE: Upserting SECONDARY device snapshot")
        print("👤 UserId: \(userId)")
        print("📱 Primary Device: \(String(primaryDeviceId.prefix(8)))...")
        print("🎯 Trust Score: \(trustScore)")
        
        let snapshotData: [String: Any] = [
            "userId": userId,
            "primaryDeviceId": primaryDeviceId,
            "trustScore": trustScore,
            "syncStatus": "synced",
            "lastUpdated": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // Store in device_snapshots collection (one doc per user)
        try await db.collection("device_snapshots")
            .document(userId)
            .setData(snapshotData, merge: true)
        
        print("✅ FIREBASE: Secondary device snapshot updated")
    }
    
    func getSecondaryDeviceSnapshot(for userId: String) async throws -> FirebaseDeviceSnapshot? {
        print("📊 FIREBASE: Querying SECONDARY device snapshot for userId: \(userId)")
        
        let snapshot = try await db.collection("device_snapshots")
            .document(userId)
            .getDocument()
        
        guard snapshot.exists,
              let data = snapshot.data() else {
            print("📊 FIREBASE: No secondary device snapshot found")
            return nil
        }
        
        let deviceSnapshot = FirebaseDeviceSnapshot(
            userId: data["userId"] as? String ?? "",
            primaryDeviceId: data["primaryDeviceId"] as? String ?? "",
            trustScore: data["trustScore"] as? Float,
            syncStatus: data["syncStatus"] as? String,
            lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue().ISO8601Format(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue().ISO8601Format()
        )
        
        print("✅ FIREBASE: Found secondary device snapshot")
        return deviceSnapshot
    }
    
    // MARK: - PRIMARY DEVICE - device_snapshots_history collection
    // This stores all PRIMARY device trust snapshots for verification
    // MARK: - PRIMARY DEVICE - device_snapshots_history collection
    // This stores all PRIMARY device trust snapshots for verification

    func addPrimaryDeviceSnapshotHistory(
        userId: String,
        deviceId: String,
        isPrimary: Bool = true,
        trustScore: Float,
        snapshotData: [String: Any]
    ) async throws {
        
        print("🔵 FIREBASE: Adding PRIMARY device snapshot history")
        print("👤 UserId: \(userId)")
        print("📱 Device: \(String(deviceId.prefix(8)))...")
        print("🎯 Trust Score: \(trustScore)")
        
        // ✅ CRITICAL: Convert all Date objects to timestamps
        let cleanedSnapshotData = convertDatesToTimestamps(snapshotData)
        
        // Now safe to serialize to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: cleanedSnapshotData)
        let snapshotDataString = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        let historyData: [String: Any] = [
            "userId": userId,
            "deviceId": deviceId,
            "isPrimary": isPrimary,
            "trustScore": trustScore,
            "syncStatus": "synced",
            "snapshotData": snapshotDataString,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        // ✅ FIXED: Use nested structure to match Firestore rules
        // Path: device_snapshots_history/{userId}/devices/{deviceId}
        try await db.collection("device_snapshots_history")
            .document(userId)           // User document
            .collection("devices")      // Devices subcollection
            .document(deviceId)         // Device document
            .setData(historyData, merge: true)  // Use merge to append/update
        
        print("✅ FIREBASE: Primary device history entry added")
        print("   📂 Path: device_snapshots_history/\(userId)/devices/\(String(deviceId.prefix(8)))...")
    }
    func getPrimaryDeviceSnapshotHistory(for userId: String, limit: Int = 20) async throws -> [FirebaseDeviceSnapshotHistory] {
        print("📊 FIREBASE: Querying PRIMARY device history for userId: \(userId)")
        
        let snapshots = try await db.collection("device_snapshots_history")
            .whereField("userId", isEqualTo: userId)
            .whereField("isPrimary", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        let history = snapshots.documents.compactMap { doc -> FirebaseDeviceSnapshotHistory? in
            let data = doc.data()
            return FirebaseDeviceSnapshotHistory(
                userId: data["userId"] as? String ?? "",
                deviceId: data["deviceId"] as? String ?? "",
                isPrimary: data["isPrimary"] as? Bool ?? false,
                trustScore: data["trustScore"] as? Float,
                syncStatus: data["syncStatus"] as? String,
                snapshotData: data["snapshotData"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue().ISO8601Format()
            )
        }
        
        print("✅ FIREBASE: Found \(history.count) primary device history entries")
        return history
    }
    
    // MARK: - Real-time Listeners
    
    func listenToSecondaryDeviceSnapshot(
        userId: String,
        onUpdate: @escaping (FirebaseDeviceSnapshot) -> Void
    ) {
        print("🔔 FIREBASE: Starting listener for SECONDARY device snapshot")
        
        let listener = db.collection("device_snapshots")
            .document(userId)
            .addSnapshotListener { snapshot, error in
                guard error == nil,
                      let snapshot = snapshot,
                      snapshot.exists,
                      let data = snapshot.data() else { return }
                
                let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                let primaryDeviceId = data["primaryDeviceId"] as? String ?? ""
                
                // Only notify if update is from different device
                if primaryDeviceId != currentDeviceId {
                    print("🔔 FIREBASE: Secondary device snapshot updated")
                    
                    let deviceSnapshot = FirebaseDeviceSnapshot(
                        userId: data["userId"] as? String ?? "",
                        primaryDeviceId: primaryDeviceId,
                        trustScore: data["trustScore"] as? Float,
                        syncStatus: data["syncStatus"] as? String,
                        lastUpdated: (data["lastUpdated"] as? Timestamp)?.dateValue().ISO8601Format(),
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue().ISO8601Format()
                    )
                    
                    DispatchQueue.main.async {
                        onUpdate(deviceSnapshot)
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    func listenToPrimaryDeviceSnapshotHistory(
        userId: String,
        onNewEntry: @escaping (FirebaseDeviceSnapshotHistory) -> Void
    ) {
        print("🔔 FIREBASE: Starting listener for PRIMARY device history")
        
        var lastSeenTimestamp: Timestamp?
        
        let listener = db.collection("device_snapshots_history")
            .whereField("userId", isEqualTo: userId)
            .whereField("isPrimary", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                guard error == nil,
                      let documents = snapshot?.documents,
                      let firstDoc = documents.first else { return }
                
                let data = firstDoc.data()
                let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                let entryDeviceId = data["deviceId"] as? String ?? ""
                let timestamp = data["createdAt"] as? Timestamp
                
                // Check if this is a new entry from a different device
                if entryDeviceId != currentDeviceId {
                    if lastSeenTimestamp == nil || timestamp != lastSeenTimestamp {
                        lastSeenTimestamp = timestamp
                        
                        print("🔔 FIREBASE: New PRIMARY device history entry")
                        
                        let entry = FirebaseDeviceSnapshotHistory(
                            userId: data["userId"] as? String ?? "",
                            deviceId: entryDeviceId,
                            isPrimary: data["isPrimary"] as? Bool ?? false,
                            trustScore: data["trustScore"] as? Float,
                            syncStatus: data["syncStatus"] as? String,
                            snapshotData: data["snapshotData"] as? String,
                            createdAt: timestamp?.dateValue().ISO8601Format()
                        )
                        
                        DispatchQueue.main.async {
                            onNewEntry(entry)
                        }
                    }
                }
            }
        
        listeners.append(listener)
    }
    
    // MARK: - User Actions
    
    func pushUserAction(
        userId: String,
        deviceId: String,
        actionType: String,
        payloadJSON: String
    ) async throws -> String {
        
        print("🔵 FIREBASE: Pushing user action - \(actionType)")
        
        let actionRef = db.collection("user_actions").document()
        
        let actionData: [String: Any] = [
            "user_id": userId,
            "device_id": deviceId,
            "type": actionType,
            "payload": payloadJSON,
            "created_at": FieldValue.serverTimestamp()
        ]
        
        try await actionRef.setData(actionData)
        print("✅ FIREBASE: Pushed user action - \(actionType) with ID: \(actionRef.documentID)")
        
        return actionRef.documentID
    }
    
    func getRecentActions(userId: String, limit: Int = 100) async throws -> [FirebaseUserAction] {
        print("📊 FIREBASE: Fetching recent actions for userId: \(userId)")
        
        let snapshot = try await db.collection("user_actions")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        var actions: [FirebaseUserAction] = []
        
        for document in snapshot.documents {
            let data = document.data()
            
            let action = FirebaseUserAction(
                id: document.documentID,
                user_id: data["user_id"] as? String ?? "",
                device_id: data["device_id"] as? String ?? "",
                type: data["type"] as? String ?? "",
                payload: data["payload"] as? String ?? "{}",
                created_at: (data["created_at"] as? Timestamp)?.dateValue().timeIntervalSince1970 ?? Date().timeIntervalSince1970
            )
            
            actions.append(action)
        }
        
        print("✅ FIREBASE: Fetched \(actions.count) actions")
        return actions
    }
    
    func listenToUserActions(
        userId: String,
        onAction: @escaping (FirebaseUserAction) -> Void
    ) -> ListenerRegistration {
        
        print("🔔 FIREBASE: Starting user actions listener for userId: \(userId)")
        
        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        let listener = db.collection("user_actions")
            .whereField("user_id", isEqualTo: userId)
            .order(by: "created_at", descending: true)
            .limit(to: 50)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot else {
                    print("❌ FIREBASE: Actions listener error - \(error?.localizedDescription ?? "unknown")")
                    return
                }
                
                for change in snapshot.documentChanges {
                    if change.type == .added {
                        let data = change.document.data()
                        let actionDeviceId = data["device_id"] as? String ?? ""
                        
                        // Only notify if action is from a different device
                        if actionDeviceId != currentDeviceId {
                            let action = FirebaseUserAction(
                                id: change.document.documentID,
                                user_id: data["user_id"] as? String ?? "",
                                device_id: actionDeviceId,
                                type: data["type"] as? String ?? "",
                                payload: data["payload"] as? String ?? "{}",
                                created_at: (data["created_at"] as? Timestamp)?.dateValue().timeIntervalSince1970 ?? Date().timeIntervalSince1970
                            )
                            
                            print("🔔 FIREBASE: Received action '\(action.type)' from device: \(String(actionDeviceId.prefix(8)))...")
                            onAction(action)
                        }
                    }
                }
            }
        
        listeners.append(listener)
        print("✅ FIREBASE: User actions listener started")
        return listener
    }
    
    func stopListening() {
        print("🛑 FIREBASE: Stopping all listeners")
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    // MARK: - Encrypted Storage (Existing functionality)
    // MARK: - Encrypted Storage (Thread-Safe)
    
    /// Upload encrypted snapshot using plain dictionary (thread-safe)
    /// Upload encrypted snapshot using plain data (thread-safe)
    func uploadEncryptedSnapshot(userId: String, snapshotId: String, codableData: TrustSnapshotData) async throws {
        do {
            print("🔐 Encrypting and uploading snapshot...")
            
            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(codableData)
            
            // Encrypt
            let encryptionKey = try generateAndStoreKeyIfNeeded()
            let sealedBox = try AES.GCM.seal(jsonData, using: encryptionKey)
            guard let encryptedData = sealedBox.combined else {
                throw NSError(domain: "FirebaseManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
            }
            
            // Upload to Storage
            let storageRef = Storage.storage().reference()
                .child("snapshots/\(userId)/\(snapshotId).enc")
            
            _ = try await storageRef.putDataAsync(encryptedData)
            
            print("✅ FIREBASE: Encrypted snapshot uploaded to Storage")
            
        } catch {
            print("❌ FIREBASE: Failed to upload encrypted snapshot: \(error)")
            throw error
        }
    }
}

    private func generateAndStoreKeyIfNeeded() throws -> SymmetricKey {
        if let storedKeyData = KeychainHelper.shared.read(service: "encryption", account: "aesKey") {
            return SymmetricKey(data: storedKeyData)
        } else {
            let newKey = SymmetricKey(size: .bits256)
            let keyData = newKey.withUnsafeBytes { Data($0) }
            KeychainHelper.shared.save(data: keyData, service: "encryption", account: "aesKey")
            return newKey
        }
    }
// MARK: - Data Models (Matching Android Schema - Renamed to avoid conflicts)

// SECONDARY DEVICE - Matches Android DeviceSnapshot data class
struct FirebaseDeviceSnapshot: Codable {
    let userId: String
    let primaryDeviceId: String
    let trustScore: Float?
    let syncStatus: String?
    let lastUpdated: String?
    let createdAt: String?
}

// PRIMARY DEVICE - Matches Android DeviceSnapshotHistory data class
struct FirebaseDeviceSnapshotHistory: Codable {
    let userId: String
    let deviceId: String
    let isPrimary: Bool
    let trustScore: Float?
    let syncStatus: String?
    let snapshotData: String? // JSON string, not dictionary
    let createdAt: String?
    
    // Helper to parse snapshotData JSON string
    var snapshotDataDict: [String: Any]? {
        guard let jsonString = snapshotData,
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
}

// MARK: - Extension for TrustSnapshot compatibility

// MARK: - Extension for TrustSnapshot compatibility

