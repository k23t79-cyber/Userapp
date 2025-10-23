import Foundation
import RealmSwift
import ZIPFoundation
import CryptoKit
import FirebaseStorage
import FirebaseFirestore
import UIKit

final class SyncManager {

    static let shared = SyncManager()
    private init() {}

    // MARK: - Configuration
    private let storageFolder = "snapshots"

    // MARK: - Single Snapshot Sync (Updated Approach)
    
    /// Sync all snapshots for a user into a single consolidated file
    func syncPendingSnapshots(completion: ((Result<Int, Error>) -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            // Create a fresh Realm instance on this background thread
            guard let backgroundRealm = try? Realm() else {
                DispatchQueue.main.async { completion?(.failure(NSError(domain: "RealmError", code: -1))) }
                return
            }
            
            do {
                let pending = backgroundRealm.objects(TrustSnapshot.self).filter("syncStatusRaw == %@", "pending")

                if pending.isEmpty {
                    print("No pending snapshots to sync")
                    DispatchQueue.main.async { completion?(.success(0)) }
                    return
                }

                // Convert to simple data structures immediately to avoid thread issues
                var snapshotData: [String: [[String: Any]]] = [:]
                
                for snapshot in pending {
                    let userId = snapshot.userId
                    let data: [String: Any] = [
                        "id": snapshot.id.stringValue,
                        "userId": snapshot.userId,
                        "deviceId": snapshot.deviceId,
                        "isJailbroken": snapshot.isJailbroken,
                        "isVPNEnabled": snapshot.isVPNEnabled,
                        "isUserInteracting": snapshot.isUserInteracting,
                        "uptimeSeconds": snapshot.uptimeSeconds,
                        "timezone": snapshot.timezone,
                        "timestamp": snapshot.timestamp.timeIntervalSince1970, // Convert Date to Unix timestamp
                        "location": snapshot.location,
                        "trustLevel": snapshot.trustLevel,
                        "score": snapshot.score,
                        "syncStatusRaw": snapshot.syncStatusRaw
                    ]
                    
                    if snapshotData[userId] == nil {
                        snapshotData[userId] = []
                    }
                    snapshotData[userId]?.append(data)
                }

                var totalSyncedCount = 0

                for (userId, snapshots) in snapshotData {
                    do {
                        // Mark as pending using the background realm
                        try backgroundRealm.write {
                            let userSnapshots = backgroundRealm.objects(TrustSnapshot.self)
                                .filter("userId == %@ AND syncStatusRaw == %@", userId, "pending")
                            for snapshot in userSnapshots {
                                snapshot.syncStatusRaw = "pending"
                            }
                        }

                        // Debug: Print the raw data before JSON conversion
                        print("🔍 Debug: About to convert \(snapshots.count) snapshots to JSON")
                        for (index, snapshot) in snapshots.enumerated() {
                            print("Snapshot \(index): \(snapshot)")
                            for (key, value) in snapshot {
                                print("  \(key): \(type(of: value)) = \(value)")
                            }
                        }
                        
                        // Convert data to JSON for upload
                        let jsonData = try self.createJSONFromData(snapshots)
                        
                        // Upload process (file operations)
                        let zipURL = try self.zipDataToTempFile(data: jsonData, fileName: "user_snapshots.json")
                        let dek = SymmetricKey(size: .bits256)
                        let encryptedURL = try self.encryptFileWithDEK(zipURL, dek: dek)
                        let syncKEK = try self.getOrCreateSyncKEK(for: userId)
                        let wrappedDEK = try self.wrapDEK(dek: dek, syncKEK: syncKEK)
                        let remotePath = "snapshots/\(userId)/snapshot.dat"
                        
                        try self.uploadFileToFirebase(localFileURL: encryptedURL, remotePath: remotePath)
                        try self.saveSnapshotMetadata(snapshotId: userId, userId: userId, storagePath: remotePath, wrappedDEK: wrappedDEK)
                        
                        // Mark as synced using the background realm
                        try backgroundRealm.write {
                            let userSnapshots = backgroundRealm.objects(TrustSnapshot.self)
                                .filter("userId == %@", userId)
                            for snapshot in userSnapshots {
                                snapshot.syncStatusRaw = "synced"
                                snapshot.syncedAt = Date()
                            }
                        }
                        
                        totalSyncedCount += snapshots.count
                        print("Successfully synced consolidated snapshot for user \(userId)")

                        // Cleanup
                        try? FileManager.default.removeItem(at: zipURL)
                        try? FileManager.default.removeItem(at: encryptedURL)

                    } catch {
                        print("Failed to sync snapshots for user \(userId): \(error)")
                        // Reset to pending on error using background realm
                        try? backgroundRealm.write {
                            let userSnapshots = backgroundRealm.objects(TrustSnapshot.self)
                                .filter("userId == %@", userId)
                            for snapshot in userSnapshots {
                                snapshot.syncStatusRaw = "pending"
                            }
                        }
                    }
                }

                print("Consolidated sync completed: \(totalSyncedCount) snapshots")
                DispatchQueue.main.async { completion?(.success(totalSyncedCount)) }
                
            } catch {
                print("Consolidated sync error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }

    // MARK: - Fixed JSON Creation Methods
    
    /// Helper method to create JSON from data - BULLETPROOF VERSION
    private func createJSONFromData(_ snapshots: [[String: Any]]) throws -> Data {
        print("📦 Creating JSON from \(snapshots.count) snapshots")
        
        // Double-process snapshots to ensure absolutely no Date objects remain
        let processedSnapshots = snapshots.map { snapshot in
            var cleanSnapshot: [String: Any] = [:]
            
            for (key, value) in snapshot {
                cleanSnapshot[key] = processDataForJSON(value)
            }
            
            return cleanSnapshot
        }
        
        let consolidatedData: [String: Any] = [
            "userId": snapshots.first?["userId"] as? String ?? "",
            "deviceId": snapshots.first?["deviceId"] as? String ?? "",
            "lastUpdated": Date().timeIntervalSince1970,
            "totalSnapshots": snapshots.count,
            "snapshots": processedSnapshots
        ]
        
        // Final validation: check if we can serialize this data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: consolidatedData, options: [])
            print("✅ JSON serialization successful: \(jsonData.count) bytes")
            return jsonData
        } catch {
            print("❌ JSON serialization failed: \(error)")
            print("🔍 Problematic data structure: \(consolidatedData)")
            throw error
        }
    }
    
    /// Recursively process any data structure to convert Date objects to timestamps
    private func processDataForJSON(_ data: Any) -> Any {
        // Handle Date objects
        if let date = data as? Date {
            print("🔄 Converting Date to timestamp: \(date) -> \(date.timeIntervalSince1970)")
            return date.timeIntervalSince1970
        }
        
        // Handle NSDate objects (in case of Objective-C bridging)
        if let nsDate = data as? NSDate {
            print("🔄 Converting NSDate to timestamp: \(nsDate) -> \(nsDate.timeIntervalSince1970)")
            return nsDate.timeIntervalSince1970
        }
        
        // Handle dictionaries recursively
        if let dict = data as? [String: Any] {
            return dict.mapValues { processDataForJSON($0) }
        }
        
        // Handle arrays recursively
        if let array = data as? [Any] {
            return array.map { processDataForJSON($0) }
        }
        
        // Handle any other NSDate subclasses or tagged dates
        if String(describing: type(of: data)).contains("Date") {
            print("🚨 Found potential Date object: \(type(of: data)) - \(data)")
            if let dateValue = data as? NSDate {
                return dateValue.timeIntervalSince1970
            }
        }
        
        return data
    }

    // MARK: - Consolidated JSON Creation
    
    /// Convert multiple snapshots into a single consolidated JSON structure
    private func consolidatedSnapshotsToJSON(snapshots: [TrustSnapshot]) throws -> Data {
        let consolidatedSnapshots = snapshots.map { snapshot in
            CodableSnapshot(
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
                syncStatus: snapshot.syncStatusRaw,  // Use raw string value
                syncedAt: snapshot.syncedAt
            )
        }

        // Create consolidated structure
        let consolidatedData = ConsolidatedUserSnapshots(
            userId: snapshots.first?.userId ?? "",
            deviceId: snapshots.first?.deviceId ?? "",
            lastUpdated: Date(),
            totalSnapshots: snapshots.count,
            snapshots: consolidatedSnapshots
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(consolidatedData)
    }

    // MARK: - Updated Metadata Structure
    
    /// Save consolidated snapshot metadata to Firestore
    private func saveSnapshotMetadata(snapshotId: String, userId: String, storagePath: String, wrappedDEK: String) throws {
        let db = Firestore.firestore()
        
        // Save to ciphertext_metadata/{userId}_latest (overwrite existing)
        let metadataRef = db.collection("ciphertext_metadata").document(userId) 
        let metadataData: [String: Any] = [
            "snapshot_id": snapshotId,
            "storage_path": storagePath,
            "wrapped_dek_reference": "wrapped_dek_entries/\(snapshotId)",
            "encryption_info": "AES-256-GCM",
            "uploaded_at": FieldValue.serverTimestamp(),
            "userId": userId,
            "version": "consolidated"  // Mark as consolidated version
        ]
        
        // Save to wrapped_dek_entries/{snapshotId} (overwrite existing)
        let dekRef = db.collection("wrapped_dek_entries").document(snapshotId)
                let dekData: [String: Any] = [
                    "wrapped_dek": wrappedDEK,
                    "snapshot_id": snapshotId,
                    "userId": userId,
                    "created_at": FieldValue.serverTimestamp(),
            "type": "consolidated"
        ]
        
        var metadataError: Error?
        var dekError: Error?
        
        let group = DispatchGroup()
        
        // Overwrite metadata
        group.enter()
        metadataRef.setData(metadataData) { error in
            metadataError = error
            group.leave()
        }
        
        // Overwrite wrapped DEK
        group.enter()
        dekRef.setData(dekData) { error in
            dekError = error
            group.leave()
        }
        
        _ = group.wait(timeout: .now() + 30)
        
        if let error = metadataError ?? dekError {
            throw error
        }
        
        print("Saved consolidated metadata for user \(userId)")
    }

    // MARK: - DEK Management (Unchanged)
    
    private func getOrCreateSyncKEK(for userId: String) throws -> SymmetricKey {
        let db = Firestore.firestore()
        let syncKeyRef = db.collection("sync_keys").document(userId)
        
        var result: SymmetricKey?
        var fetchError: Error?
        
        let group = DispatchGroup()
        group.enter()
        
        syncKeyRef.getDocument { document, error in
            if let error = error {
                fetchError = error
                group.leave()
                return
            }
            
            if let document = document, document.exists,
               let data = document.data(),
               let syncKEKBase64 = data["sync_kek"] as? String,
               let syncKEKData = Data(base64Encoded: syncKEKBase64) {
                result = SymmetricKey(data: syncKEKData)
                print("Retrieved existing SyncKEK for user \(userId)")
                group.leave()
            } else {
                let newSyncKEK = SymmetricKey(size: .bits256)
                let syncKEKData = newSyncKEK.withUnsafeBytes { Data($0) }
                let syncKEKBase64 = syncKEKData.base64EncodedString()
                
                let newData: [String: Any] = [
                    "sync_kek": syncKEKBase64,
                    "created_at": FieldValue.serverTimestamp(),
                    "userId": userId
                ]
                
                syncKeyRef.setData(newData) { error in
                    if let error = error {
                        fetchError = error
                    } else {
                        result = newSyncKEK
                        print("Created new SyncKEK for user \(userId)")
                    }
                    group.leave()
                }
            }
        }
        
        _ = group.wait(timeout: .now() + 30)
        
        if let error = fetchError {
            throw error
        }
        
        guard let syncKEK = result else {
            throw NSError(domain: "SyncKEKError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get SyncKEK"])
        }
        
        return syncKEK
    }
    
    private func wrapDEK(dek: SymmetricKey, syncKEK: SymmetricKey) throws -> String {
        let dekData = dek.withUnsafeBytes { Data($0) }
        let sealedBox = try AES.GCM.seal(dekData, using: syncKEK)
        return sealedBox.combined!.base64EncodedString()
    }

    // MARK: - File Operations (Unchanged)
    
    private func zipDataToTempFile(data: Data, fileName: String) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let jsonURL = tmpDir.appendingPathComponent(fileName)
        try data.write(to: jsonURL)

        let archiveURL = tmpDir.appendingPathComponent(fileName.replacingOccurrences(of: ".json", with: ".zip"))

        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }

        guard let archive = Archive(url: archiveURL, accessMode: .create) else {
            throw NSError(domain: "zip", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive"])
        }

        try archive.addEntry(with: jsonURL.lastPathComponent, fileURL: jsonURL, compressionMethod: .deflate)
        try? FileManager.default.removeItem(at: jsonURL)

        return archiveURL
    }

    private func encryptFileWithDEK(_ fileURL: URL, dek: SymmetricKey) throws -> URL {
        let data = try Data(contentsOf: fileURL)
        let sealedBox = try AES.GCM.seal(data, using: dek)
        let combined = sealedBox.combined!

        let outURL = fileURL.deletingPathExtension().appendingPathExtension("dat")
        try combined.write(to: outURL)
        return outURL
    }

    private func uploadFileToFirebase(localFileURL: URL, remotePath: String) throws {
        let storageRef = Storage.storage().reference()
        let fileRef = storageRef.child(remotePath)

        var uploadError: Error?
        let group = DispatchGroup()
        group.enter()

        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"

        fileRef.putFile(from: localFileURL, metadata: metadata) { metadata, error in
            if let error = error {
                uploadError = error
            } else {
                print("Uploaded consolidated snapshot to: \(remotePath)")
            }
            group.leave()
        }

        let waitResult = group.wait(timeout: .now() + 60)
        if waitResult == .timedOut {
            throw NSError(domain: "firebase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Upload timed out"])
        }
        if let e = uploadError { throw e }
    }
}

// MARK: - Consolidated Data Models
struct ConsolidatedUserSnapshots: Codable {
    let userId: String
    let deviceId: String
    let lastUpdated: Date
    let totalSnapshots: Int
    let snapshots: [CodableSnapshot]
}
