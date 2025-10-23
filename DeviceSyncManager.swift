import Foundation
import RealmSwift
import ZIPFoundation
import CryptoKit
import FirebaseStorage
import FirebaseFirestore
import UIKit

final class DeviceSyncManager {
    
    static let shared = DeviceSyncManager()
    private init() {}
    
    // MARK: - Configuration
    private let storageFolder = "snapshots"
    
    /// Main entry: Download and restore latest snapshot from cloud to current device
    func syncFromCloud(for userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        print("Starting device sync for user: \(userId)")
        
        DispatchQueue.global(qos: .background).async {
            do {
                // Step 1: Get latest snapshot metadata from Firestore
                let metadata = try self.fetchSnapshotMetadata(for: userId)
                print("✅ Found metadata for snapshot: \(metadata.snapshotId)")
                
                // Step 2: Fetch SyncKEK from Firestore
                let syncKEK = try self.fetchSyncKEK(for: userId)
                print("✅ Retrieved SyncKEK for user")
                
                // Step 3: Fetch wrapped DEK from Firestore
                let wrappedDEK = try self.fetchWrappedDEK(snapshotId: metadata.snapshotId)
                print("✅ Retrieved wrapped DEK")
                
                // Step 4: Unwrap DEK using SyncKEK
                let dek = try self.unwrapDEK(wrappedDEK: wrappedDEK, syncKEK: syncKEK)
                print("✅ Successfully unwrapped DEK")
                
                // Step 5: Download encrypted snapshot from Firebase Storage
                let encryptedData = try self.downloadSnapshotFromStorage(path: metadata.storagePath)
                print("✅ Downloaded encrypted snapshot (\(encryptedData.count) bytes)")
                
                // Step 6: Decrypt snapshot using DEK
                let decryptedData = try self.decryptSnapshot(encryptedData: encryptedData, dek: dek)
                print("✅ Decrypted snapshot data")
                
                // Step 7: Unzip and parse snapshot
                let snapshots = try self.unzipAndParseSnapshots(data: decryptedData)
                print("✅ Parsed \(snapshots.count) snapshots from archive")
                
                // Step 8: Save to local Realm database
                let restoredCount = try self.saveSnapshotsToRealm(snapshots: snapshots)
                print("✅ Restored \(restoredCount) snapshots to local database")
                
                DispatchQueue.main.async {
                    completion(.success(restoredCount))
                }
                
            } catch {
                print("❌ Device sync failed: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Step 1: Fetch Snapshot Metadata
    private func fetchSnapshotMetadata(for userId: String) throws -> SnapshotMetadata {
        let db = Firestore.firestore()
        
        let metadataRef = db.collection("ciphertext_metadata")
            .document(userId)
        
        var result: SnapshotMetadata?
        var fetchError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        metadataRef.getDocument { document, error in
            if let error = error {
                fetchError = error
            } else if let document = document, document.exists,
                      var data = document.data() {
                do {
                    // ✅ CRITICAL FIX: Convert Firestore Timestamps BEFORE JSON serialization
                    data = self.convertFirestoreTimestamps(data)
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    result = try JSONDecoder().decode(SnapshotMetadata.self, from: jsonData)
                } catch {
                    print("❌ Failed to decode metadata: \(error)")
                    fetchError = error
                }
            } else {
                fetchError = SyncError.noMetadata
            }
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 30)
        
        if let error = fetchError {
            throw error
        }
        
        guard let metadata = result else {
            throw SyncError.noMetadata
        }
        
        return metadata
    }
    
    // ✅ Convert Firestore Timestamps to ISO8601 strings
    private func convertFirestoreTimestamps(_ data: [String: Any]) -> [String: Any] {
        var converted = data
        
        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                let date = timestamp.dateValue()
                converted[key] = ISO8601DateFormatter().string(from: date)
            } else if let nestedDict = value as? [String: Any] {
                converted[key] = convertFirestoreTimestamps(nestedDict)
            } else if let array = value as? [[String: Any]] {
                converted[key] = array.map { convertFirestoreTimestamps($0) }
            }
        }
        
        return converted
    }
    
    // MARK: - Step 2: Fetch SyncKEK
    private func fetchSyncKEK(for userId: String) throws -> SymmetricKey {
        let db = Firestore.firestore()
        let syncKeyRef = db.collection("sync_keys").document(userId)
        
        var result: SymmetricKey?
        var fetchError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        syncKeyRef.getDocument { document, error in
            if let error = error {
                fetchError = error
            } else if let document = document, document.exists,
                      let data = document.data(),
                      let syncKEKBase64 = data["sync_kek"] as? String,
                      let syncKEKData = Data(base64Encoded: syncKEKBase64) {
                result = SymmetricKey(data: syncKEKData)
            } else {
                fetchError = SyncError.noSyncKEK
            }
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 30)
        
        if let error = fetchError {
            throw error
        }
        
        guard let syncKEK = result else {
            throw SyncError.noSyncKEK
        }
        
        return syncKEK
    }
    
    // MARK: - Step 3: Fetch Wrapped DEK
    private func fetchWrappedDEK(snapshotId: String) throws -> String {
        let db = Firestore.firestore()
        let dekRef = db.collection("wrapped_dek_entries").document(snapshotId)
        
        var result: String?
        var fetchError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        dekRef.getDocument { document, error in
            if let error = error {
                fetchError = error
            } else if let document = document, document.exists,
                      let data = document.data(),
                      let wrappedDEK = data["wrapped_dek"] as? String {
                result = wrappedDEK
            } else {
                fetchError = SyncError.invalidDEK
            }
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 30)
        
        if let error = fetchError {
            throw error
        }
        
        guard let wrappedDEK = result else {
            throw SyncError.invalidDEK
        }
        
        return wrappedDEK
    }
    
    // MARK: - Step 4: Unwrap DEK
    private func unwrapDEK(wrappedDEK: String, syncKEK: SymmetricKey) throws -> SymmetricKey {
        guard let wrappedDEKData = Data(base64Encoded: wrappedDEK) else {
            throw SyncError.invalidDEK
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: wrappedDEKData)
        let dekData = try AES.GCM.open(sealedBox, using: syncKEK)
        
        return SymmetricKey(data: dekData)
    }
    
    // MARK: - Step 5: Download from Firebase Storage
    private func downloadSnapshotFromStorage(path: String) throws -> Data {
        let storageRef = Storage.storage().reference()
        let fileRef = storageRef.child(path)
        
        var result: Data?
        var downloadError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        fileRef.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                downloadError = error
            } else {
                result = data
            }
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 60)
        
        if let error = downloadError {
            throw error
        }
        
        guard let data = result else {
            throw SyncError.downloadFailed
        }
        
        return data
    }
    
    // MARK: - Step 6: Decrypt Snapshot
    private func decryptSnapshot(encryptedData: Data, dek: SymmetricKey) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: dek)
        } catch {
            throw SyncError.decryptionFailed
        }
    }
    
    // MARK: - Step 7: Unzip and Parse Snapshots (COMPREHENSIVE FIX)
    private func unzipAndParseSnapshots(data: Data) throws -> [CodableSnapshot] {
        let tempDir = FileManager.default.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("downloaded_snapshot_\(UUID().uuidString).zip")
        try data.write(to: zipURL)
        
        let extractDir = tempDir.appendingPathComponent("extracted_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        
        guard let archive = Archive(url: zipURL, accessMode: .read) else {
            throw SyncError.unzipFailed
        }
        
        var snapshots: [CodableSnapshot] = []
        
        for entry in archive {
            let extractedURL = extractDir.appendingPathComponent(entry.path)
            _ = try archive.extract(entry, to: extractedURL)
            
            if extractedURL.pathExtension == "json" {
                let jsonData = try Data(contentsOf: extractedURL)
                
                // ✅ DEBUG: Log JSON structure
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("📦 Raw JSON (first 300 chars): \(String(jsonString.prefix(300)))")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    
                    if let dateString = try? container.decode(String.self) {
                        if let date = ISO8601DateFormatter().date(from: dateString) {
                            return date
                        }
                    }
                    
                    if let timestamp = try? container.decode(Double.self) {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
                }
                
                // ✅ STRATEGY 1: Try as ConsolidatedUserSnapshots
                do {
                    let consolidated = try decoder.decode(ConsolidatedUserSnapshots.self, from: jsonData)
                    snapshots.append(contentsOf: consolidated.snapshots)
                    print("✅ Decoded as ConsolidatedUserSnapshots: \(consolidated.snapshots.count) snapshots")
                    continue
                } catch {
                    print("⚠️ Not ConsolidatedUserSnapshots format")
                }
                
                // ✅ STRATEGY 2: Try as array
                do {
                    let snapshotArray = try decoder.decode([CodableSnapshot].self, from: jsonData)
                    snapshots.append(contentsOf: snapshotArray)
                    print("✅ Decoded as array: \(snapshotArray.count) snapshots")
                    continue
                } catch {
                    print("⚠️ Not array format")
                }
                
                // ✅ STRATEGY 3: Try as single snapshot
                do {
                    let snapshot = try decoder.decode(CodableSnapshot.self, from: jsonData)
                    snapshots.append(snapshot)
                    print("✅ Decoded as single snapshot")
                    continue
                } catch {
                    print("⚠️ Not single snapshot format")
                }
                
                // ✅ STRATEGY 4: Try as dictionary with "snapshots" key
                if let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    print("📦 Dictionary keys: \(dict.keys.joined(separator: ", "))")
                    
                    if let snapshotsArray = dict["snapshots"] as? [[String: Any]] {
                        print("🔍 Found 'snapshots' array with \(snapshotsArray.count) items")
                        
                        for snapshotDict in snapshotsArray {
                            if let snapshotData = try? JSONSerialization.data(withJSONObject: snapshotDict),
                               let snapshot = try? decoder.decode(CodableSnapshot.self, from: snapshotData) {
                                snapshots.append(snapshot)
                            }
                        }
                        
                        if !snapshots.isEmpty {
                            print("✅ Decoded \(snapshots.count) snapshots from dictionary")
                            continue
                        }
                    }
                }
                
                print("❌ All decoding strategies failed")
                throw SyncError.decodingFailed
            }
        }
        
        try? FileManager.default.removeItem(at: zipURL)
        try? FileManager.default.removeItem(at: extractDir)
        
        if snapshots.isEmpty {
            throw SyncError.decodingFailed
        }
        
        return snapshots
    }
    
    // MARK: - Step 8: Save to Realm
    private func saveSnapshotsToRealm(snapshots: [CodableSnapshot]) throws -> Int {
        let realm = try Realm()
        var savedCount = 0
        
        try realm.write {
            for codableSnapshot in snapshots {
                let existingSnapshot = realm.objects(TrustSnapshot.self)
                    .filter("userId == %@ AND timestamp == %@", codableSnapshot.userId, codableSnapshot.timestamp)
                    .first
                
                if existingSnapshot == nil {
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
                    trustSnapshot.score = Int(Double(codableSnapshot.score))
                    trustSnapshot.syncStatusRaw = "synced"
                    trustSnapshot.syncedAt = Date()
                    
                    realm.add(trustSnapshot)
                    savedCount += 1
                    print("✅ Restored snapshot: \(codableSnapshot.id)")
                } else {
                    print("⚠️ Skipped duplicate snapshot: \(codableSnapshot.id)")
                }
            }
        }
        
        return savedCount
    }
}

// MARK: - Data Models
struct SnapshotMetadata: Codable {
    let snapshotId: String
    let storagePath: String
    let wrappedDEKReference: String
    let encryptionInfo: String
    let uploadedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case snapshotId = "snapshot_id"
        case storagePath = "storage_path"
        case wrappedDEKReference = "wrapped_dek_reference"
        case encryptionInfo = "encryption_info"
        case uploadedAt = "uploaded_at"
    }
}

struct CodableSnapshot: Codable {
    var id: String
    var userId: String
    var deviceId: String
    var isJailbroken: Bool
    var isVPNEnabled: Bool
    var isUserInteracting: Bool
    var uptimeSeconds: Int
    var timezone: String
    var timestamp: Date
    var location: String
    var trustLevel: Int
    var score: Int
    var syncStatus: String
    var syncedAt: Date?
}

// ✅ Add ConsolidatedUserSnapshots to match SyncManager format

// MARK: - Sync Errors
enum SyncError: Error, LocalizedError {
    case noMetadata
    case noSyncKEK
    case invalidDEK
    case decryptionFailed
    case downloadFailed
    case unzipFailed
    case databaseError
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noMetadata: return "No snapshot metadata found"
        case .noSyncKEK: return "SyncKEK not found"
        case .invalidDEK: return "Invalid DEK format"
        case .decryptionFailed: return "Failed to decrypt snapshot"
        case .downloadFailed: return "Failed to download snapshot"
        case .unzipFailed: return "Failed to unzip snapshot"
        case .databaseError: return "Database error"
        case .decodingFailed: return "Failed to decode snapshot data"
        }
    }
}
