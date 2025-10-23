//
//  DeviceUtils.swift
//  Userapp
//
//  Created by Ri on 7/28/25.
//


import Foundation
import UIKit
import SystemConfiguration.CaptiveNetwork
import CommonCrypto

class DeviceUtils {
    
    // 1. Uptime (seconds since last reboot)
    static func getDeviceUptime() -> TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }

    // 2. Device Signature (hashed identifier)
    static func getHashedDeviceSignature() -> String {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        return sha256(deviceId)
    }

    // 3. SHA-256 Hasher
    private static func sha256(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
