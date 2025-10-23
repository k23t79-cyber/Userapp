import Foundation
import ZIPFoundation
import RealmSwift
import FirebaseStorage
import CryptoKit

class FirebaseUploader {

    static let shared = FirebaseUploader()
    private init() {}

    func uploadSnapshot(_ snapshot: TrustSnapshot, completion: @escaping (Bool) -> Void) {
        do {
            // 1️⃣ Convert snapshot to JSON file
            let jsonURL = try saveSnapshotToJSON(snapshot)

            // 2️⃣ Zip the JSON file
            let zipURL = jsonURL.deletingPathExtension().appendingPathExtension("zip")
            try zipFiles(files: [jsonURL], to: zipURL)

            // 3️⃣ Encrypt the ZIP file
            let encryptionKey = try generateAndStoreKeyIfNeeded()
            let encryptedData = try encryptFile(at: zipURL, using: encryptionKey)

            // 4️⃣ Save encrypted file to temp URL
            let encryptedFileURL = zipURL.deletingPathExtension().appendingPathExtension("enc")
            try encryptedData.write(to: encryptedFileURL)

            // 5️⃣ Upload to Firebase Storage
            let storageRef = Storage.storage().reference().child("snapshots/\(snapshot.id).enc")
            storageRef.putFile(from: encryptedFileURL, metadata: nil) { _, error in
                if let error = error {
                    print("❌ Firebase upload failed: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Encrypted snapshot uploaded to Firebase Storage")
                    completion(true)
                }
            }

        } catch {
            print("❌ Snapshot upload process failed: \(error.localizedDescription)")
            completion(false)
        }
    }

    // MARK: - JSON Save
    private func saveSnapshotToJSON(_ snapshot: TrustSnapshot) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot.toCodable())

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(snapshot.id.stringValue)
            .appendingPathExtension("json")

        try data.write(to: fileURL)
        return fileURL
    }

    // MARK: - ZIP Helper
    private func zipFiles(files: [URL], to destination: URL) throws {
        let archive = try Archive(url: destination, accessMode: .create)
        for file in files {
            try archive.addEntry(with: file.lastPathComponent, fileURL: file)
        }
    }

    // MARK: - AES-256 Encryption Helper
    private func encryptFile(at fileURL: URL, using key: SymmetricKey) throws -> Data {
        let fileData = try Data(contentsOf: fileURL)
        let sealedBox = try AES.GCM.seal(fileData, using: key)
        return sealedBox.combined!
    }

    // MARK: - Keychain AES Key Storage
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
}

// MARK: - Codable Conversion for TrustSnapshot
extension TrustSnapshot {
    func toCodable() -> TrustSnapshotCodable {
        return TrustSnapshotCodable(
            id: id.stringValue,
            userId: userId,
            deviceId: deviceId,
            isJailbroken: isJailbroken,
            isVPNEnabled: isVPNEnabled,
            isUserInteracting: isUserInteracting,
            uptimeSeconds: uptimeSeconds,
            timezone: timezone,
            timestamp: timestamp,
            location: location,
            trustLevel: trustLevel,
            score: Int(score),
            syncStatus: syncStatus.rawValue,
            syncedAt: syncedAt
        )
    }
}

struct TrustSnapshotCodable: Codable {
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
