//
//  AESEncryption.swift
//  Userapp
//
//  Created by Ri on 8/13/25.
//


//
//  AESEncryption.swift
//  Userapp
//

import Foundation
import CommonCrypto
import Security

class AESEncryption {
    static let shared = AESEncryption()
    private let keySize = kCCKeySizeAES256
    private let keychainService = "encryption"
    private let keychainAccount = "aesKey"
    
    private init() {}
    
    // MARK: - Generate or Retrieve AES Key
    private func getOrCreateKey() throws -> Data {
        // Try to get key from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess {
            return item as! Data
        }
        
        // If not found, generate new key
        var keyData = Data(count: keySize)
        _ = keyData.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, keySize, $0.baseAddress!) }
        
        // Store in Keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
        
        print("🔑 New AES key generated and stored in Keychain.")
        return keyData
    }
    
    // MARK: - Encrypt
    func encrypt(data: Data) throws -> Data {
        let key = try getOrCreateKey()
        
        let ivSize = kCCBlockSizeAES128
        var iv = Data(count: ivSize)
        _ = iv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, ivSize, $0.baseAddress!) }
        
        let cryptLength = size_t(data.count + kCCBlockSizeAES128)
        var cryptData = Data(count: cryptLength)
        
        var numBytesEncrypted: size_t = 0
        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, keySize,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            cryptBytes.baseAddress, cryptLength,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw NSError(domain: "AESEncryption", code: Int(status), userInfo: nil)
        }
        
        cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
        
        // Return iv + encryptedData
        return iv + cryptData
    }
    
    // MARK: - Decrypt
    func decrypt(data: Data) throws -> Data {
        let key = try getOrCreateKey()
        
        let ivSize = kCCBlockSizeAES128
        let iv = data.subdata(in: 0..<ivSize)
        let encryptedData = data.subdata(in: ivSize..<data.count)
        
        let cryptLength = size_t(encryptedData.count + kCCBlockSizeAES128)
        var decryptedData = Data(count: cryptLength)
        
        var numBytesDecrypted: size_t = 0
        let status = decryptedData.withUnsafeMutableBytes { cryptBytes in
            encryptedData.withUnsafeBytes { encBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, keySize,
                            ivBytes.baseAddress,
                            encBytes.baseAddress, encryptedData.count,
                            cryptBytes.baseAddress, cryptLength,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw NSError(domain: "AESEncryption", code: Int(status), userInfo: nil)
        }
        
        decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
        return decryptedData
    }
}
