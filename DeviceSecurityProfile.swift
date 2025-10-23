//
//  DeviceSecurityProfile.swift
//  Userapp
//
//  Created by Ri on 20/10/25.
//


// DeviceSecurityProfileManager.swift
// Put this into your app target (not tests)

import Foundation
import UIKit
import LocalAuthentication
import DeviceCheck
import Security

public struct DeviceSecurityProfile: Codable {
    public let deviceId: String           // app-scoped device id (UUID) or vendor id
    public let manufacturer: String
    public let model: String
    public let modelIdentifier: String
    public let iosVersion: String
    public let buildVersion: String?
    public let secureEnclaveAvailable: Bool
    public let appAttestSupported: Bool
    public let biometricType: String?     // "FACE_ID", "TOUCH_ID", or nil
    public let timestampISO: String      // when profile was created
    public let probeDurationMs: Int      // time taken to probe in ms
}

public struct UniversalDeviceProfile: Codable {
    // Minimal universal mapping used by your UniversalAttestationResponse's device metadata
    public let platform: String // "iOS"
    public let manufacturer: String
    public let model: String
    public let modelIdentifier: String
    public let iosVersion: String
    public let secureEnclave: Bool
    public let appAttest: Bool
    public let biometricType: String?
    public let generatedAt: String
}

public final class DeviceSecurityProfileManager {

    // Singleton for easy access
    public static let shared = DeviceSecurityProfileManager()

    // In-memory cache
    private var cachedProfile: DeviceSecurityProfile?
    private let cacheQueue = DispatchQueue(label: "com.yourapp.DeviceSecurityProfile.cache")

    // Public fast-sync accessor (returns cached result if available)
    public func getCachedProfile() -> DeviceSecurityProfile? {
        return cacheQueue.sync { cachedProfile }
    }

    // Public async probe (fast) - runs device probes and returns a profile
    // completion is called on the main queue
    public func probeDeviceProfile(completion: @escaping (DeviceSecurityProfile) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let start = DispatchTime.now()
            let profile = self.createProfile()
            let end = DispatchTime.now()
            let nano = end.uptimeNanoseconds - start.uptimeNanoseconds
            let ms = Int(Double(nano) / 1_000_000.0)

            let finalProfile = DeviceSecurityProfile(
                deviceId: profile.deviceId,
                manufacturer: profile.manufacturer,
                model: profile.model,
                modelIdentifier: profile.modelIdentifier,
                iosVersion: profile.iosVersion,
                buildVersion: profile.buildVersion,
                secureEnclaveAvailable: profile.secureEnclaveAvailable,
                appAttestSupported: profile.appAttestSupported,
                biometricType: profile.biometricType,
                timestampISO: ISO8601DateFormatter().string(from: Date()),
                probeDurationMs: ms
            )

            // cache
            self.cacheQueue.sync { self.cachedProfile = finalProfile }

            DispatchQueue.main.async {
                completion(finalProfile)
            }
        }
    }

    // Convenience to produce the UniversalDeviceProfile
    public func universalProfile(from profile: DeviceSecurityProfile) -> UniversalDeviceProfile {
        return UniversalDeviceProfile(
            platform: "iOS",
            manufacturer: profile.manufacturer,
            model: profile.model,
            modelIdentifier: profile.modelIdentifier,
            iosVersion: profile.iosVersion,
            secureEnclave: profile.secureEnclaveAvailable,
            appAttest: profile.appAttestSupported,
            biometricType: profile.biometricType,
            generatedAt: profile.timestampISO
        )
    }

    // MARK: - Internal probing logic
    private func createProfile() -> DeviceSecurityProfile {
        let device = UIDevice.current

        // device id: use identifierForVendor as app-scoped ID (safe & persistent per install/vendor)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // model (e.g., "iPhone") and modelIdentifier (e.g., "iPhone16,1")
        let model = device.model
        let modelIdentifier = DeviceSecurityProfileManager.readModelIdentifier()

        let iosVersion = UIDevice.current.systemVersion
        let buildVersion = DeviceSecurityProfileManager.readBuildVersion() // optional, best-effort

        // App Attest support
        let appAttestSupported = DCAppAttestService.shared.isSupported

        // Secure Enclave presence check (fast, non-persistent key creation attempt)
        let secureEnclaveAvailable = DeviceSecurityProfileManager.checkSecureEnclaveAvailability()

        // Biometric type
        let biometricType = DeviceSecurityProfileManager.currentBiometricType()

        // create a tentative profile with probeDuration placeholder (will be overwritten by outer caller)
        return DeviceSecurityProfile(
            deviceId: deviceId,
            manufacturer: "Apple",
            model: model,
            modelIdentifier: modelIdentifier,
            iosVersion: iosVersion,
            buildVersion: buildVersion,
            secureEnclaveAvailable: secureEnclaveAvailable,
            appAttestSupported: appAttestSupported,
            biometricType: biometricType,
            timestampISO: ISO8601DateFormatter().string(from: Date()),
            probeDurationMs: 0
        )
    }

    // MARK: - Low-level helpers

    private static func readModelIdentifier() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machineMirror = Mirror(reflecting: sysinfo.machine)
        let identifier = machineMirror.children.reduce("") { acc, elem in
            guard let value = elem.value as? Int8, value != 0 else { return acc }
            return acc + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private static func readBuildVersion() -> String? {
        // Try to read CFBundleVersion from main bundle as a proxy for build version
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    private static func checkSecureEnclaveAvailability() -> Bool {
        // Attempt to create a transient, non-persistent EC key in Secure Enclave (will succeed quickly or fail)
        let params: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [kSecAttrIsPermanent as String: false]
        ]
        var error: Unmanaged<CFError>?
        if let _ = SecKeyCreateRandomKey(params as CFDictionary, &error) {
            return true
        } else {
            // if creation fails for any reason, treat as not available (safe fallback)
            return false
        }
    }

    private static func currentBiometricType() -> String? {
        let ctx = LAContext()
        var error: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch ctx.biometryType {
                case .faceID: return "FACE_ID"
                case .touchID: return "TOUCH_ID"
                default: return nil
            }
        }
        return nil
    }
}
