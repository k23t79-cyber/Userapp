import Foundation
import DeviceCheck
import CryptoKit

final class UserAppAttestManager {

    static let shared = UserAppAttestManager()
    private init() {}

    private let service = DCAppAttestService.shared
    private let keyIdKey = "appattest_key_id"

    // MARK: - Support Check
    func isSupported() -> Bool {
        return service.isSupported  // property, not function
    }

    // MARK: - Key Generation
    func generateKeyIfNeeded(completion: @escaping (String?) -> Void) {
        if let existing = UserDefaults.standard.string(forKey: keyIdKey) {
            print("🔑 App Attest key already exists: \(existing.prefix(8))…")
            completion(existing)
            return
        }

        guard service.isSupported else {
            print("❌ App Attest not supported on this device")
            completion(nil)
            return
        }

        service.generateKey { keyId, error in
            if let error = error {
                print("❌ Failed to generate App Attest key: \(error)")
                completion(nil)
            } else if let keyId = keyId {
                print("✅ Generated App Attest key: \(keyId.prefix(8))…")
                UserDefaults.standard.set(keyId, forKey: self.keyIdKey)
                completion(keyId)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Attestation
    func attestKey(using challenge: Data, completion: @escaping (Data?) -> Void) {
        guard let keyId = UserDefaults.standard.string(forKey: keyIdKey) else {
            print("❌ No App Attest key ID found.")
            completion(nil)
            return
        }

        let clientDataHash = Data(SHA256.hash(data: challenge))

        service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
            if let error = error {
                print("❌ App Attest attestation failed: \(error)")
                completion(nil)
            } else if let attestation = attestation {
                print("✅ Received attestation object (\(attestation.count) bytes)")
                completion(attestation)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Local Signing (optional)
    func sign(challenge: Data) -> Data? {
        guard let keyId = UserDefaults.standard.string(forKey: keyIdKey) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyId,
            kSecReturnRef as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        let key = item as! SecKey

        var error: Unmanaged<CFError>?
        let sig = SecKeyCreateSignature(key,
                                        .ecdsaSignatureMessageX962SHA256,
                                        challenge as CFData,
                                        &error)
        return sig as Data?
    }
}
// Add to UserAppAttestManager.swift

extension UserAppAttestManager {
    
    func performAttestation(challenge: Data, completion: @escaping (Result<Data, Error>) -> Void) {
        // Use the same key as generateKeyIfNeeded stores
        guard let keyId = UserDefaults.standard.string(forKey: "app_attest_key_id") else {
            let error = NSError(
                domain: "AppAttest",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No key ID available. Generate key first."]
            )
            completion(.failure(error))
            return
        }
        
        DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: challenge) { assertionObject, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let assertionObject = assertionObject else {
                let error = NSError(
                    domain: "AppAttest",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "No assertion object returned"]
                )
                completion(.failure(error))
                return
            }
            
            completion(.success(assertionObject))
        }
    }
}

