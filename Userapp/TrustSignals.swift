//
//  TrustSignals.swift
//  Userapp
//
//  Unified trust signals model for baseline comparison and Supabase storage
//

import Foundation

struct TrustSignals: Codable {
    // MARK: - Current Signals (Collected Now)
    let deviceId: String
    let email: String
    let isJailbroken: Bool
    let isVPNEnabled: Bool
    let isUserInteracting: Bool
    let uptimeSeconds: Int
    let timezone: String
    let ipAddress: String
    let location: String?
    let timestamp: Date
    let batteryLevel: Float
    let systemVersion: String
    let networkType: String
    
    
    // ✅ Motion Data
    let motionState: String  // "moving", "still", or "unknown"
    let motionMagnitude: Double
    
    // ✅ App Attest Data (MUST come before stored baseline fields)
    let appAttestVerified: Bool
    let appAttestScore: Int
    let appAttestRiskLevel: String
    let appAttestKeyId: String
    
    // MARK: - Baseline Signals (From Stored Data)
    let storedDeviceId: String?
    let storedEmail: String?
    let storedTimezone: String?
    let storedIpAddress: String?
    let storedLocation: String?
    let storedSystemVersion: String?
    let storedNetworkType: String?
    
    // MARK: - Additional Context
    let locationVisitCount: Int
    let userId: String
    
    // MARK: - Computed Properties
    
    var uptimeMinutes: Int {
        return uptimeSeconds / 60
    }
    
    var isNewDevice: Bool {
        guard let stored = storedDeviceId else { return true }
        return deviceId != stored
    }
    
    // ✅ Motion state enum helper
    var motion: MotionState {
        return MotionState(rawValue: motionState) ?? .unknown
    }
    
    // MARK: - Serialization for Supabase
    
    /// Convert to dictionary for Supabase JSONB storage
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "deviceId": deviceId,
            "email": email,
            "isJailbroken": isJailbroken,
            "isVPNEnabled": isVPNEnabled,
            "isUserInteracting": isUserInteracting,
            "uptimeSeconds": uptimeSeconds,
            "timezone": timezone,
            "ipAddress": ipAddress,
            "timestamp": timestamp.timeIntervalSince1970,
            "batteryLevel": batteryLevel,
            "systemVersion": systemVersion,
            "networkType": networkType,
            "locationVisitCount": locationVisitCount,
            "userId": userId,
            "motionState": motionState,
            "motionMagnitude": motionMagnitude,
            "appAttestVerified": appAttestVerified,
            "appAttestScore": appAttestScore,
            "appAttestRiskLevel": appAttestRiskLevel,
            "appAttestKeyId": appAttestKeyId
        ]
        
        if let location = location {
            dict["location"] = location
        }
        
        return dict
    }
    
    /// Create from dictionary (when reading from Supabase)
    static func fromDictionary(_ data: [String: Any]) -> TrustSignals? {
        guard let deviceId = data["deviceId"] as? String,
              let email = data["email"] as? String,
              let userId = data["userId"] as? String else {
            return nil
        }
        
        let timestamp: Date
        if let timestampDouble = data["timestamp"] as? Double {
            timestamp = Date(timeIntervalSince1970: timestampDouble)
        } else {
            timestamp = Date()
        }
        
        return TrustSignals(
            deviceId: deviceId,
            email: email,
            isJailbroken: data["isJailbroken"] as? Bool ?? false,
            isVPNEnabled: data["isVPNEnabled"] as? Bool ?? false,
            isUserInteracting: data["isUserInteracting"] as? Bool ?? true,
            uptimeSeconds: data["uptimeSeconds"] as? Int ?? 0,
            timezone: data["timezone"] as? String ?? "Unknown",
            ipAddress: data["ipAddress"] as? String ?? "unknown",
            location: data["location"] as? String,
            timestamp: timestamp,
            batteryLevel: data["batteryLevel"] as? Float ?? 0.5,
            systemVersion: data["systemVersion"] as? String ?? "Unknown",
            networkType: data["networkType"] as? String ?? "Unknown",
            motionState: data["motionState"] as? String ?? MotionState.unknown.rawValue,
            motionMagnitude: data["motionMagnitude"] as? Double ?? 0.0,
            appAttestVerified: data["appAttestVerified"] as? Bool ?? false,
            appAttestScore: data["appAttestScore"] as? Int ?? 0,
            appAttestRiskLevel: data["appAttestRiskLevel"] as? String ?? "unknown",
            appAttestKeyId: data["appAttestKeyId"] as? String ?? "",
            storedDeviceId: nil,
            storedEmail: nil,
            storedTimezone: nil,
            storedIpAddress: nil,
            storedLocation: nil,
            storedSystemVersion: nil,
            storedNetworkType: nil,
            locationVisitCount: data["locationVisitCount"] as? Int ?? 0,
            userId: userId
        )
    }
    
    // MARK: - Debug Description
    
    func debugDescription() -> String {
        let motionEmoji = motion == .still ? "🧘" : (motion == .moving ? "🏃" : "❓")
        let attestEmoji = appAttestVerified ? "🔐" : "❌"
        
        return """
        📊 Trust Signals:
        Device: \(String(deviceId.prefix(8)))... (New: \(isNewDevice))
        Email: \(email)
        Jailbroken: \(isJailbroken ? "❌ YES" : "✅ NO")
        VPN: \(isVPNEnabled ? "⚠️ YES" : "✅ NO")
        User Interacting: \(isUserInteracting ? "✅ YES" : "❌ NO")
        Uptime: \(uptimeMinutes) mins
        Timezone: \(timezone) (Stored: \(storedTimezone ?? "N/A"))
        IP: \(ipAddress) (Stored: \(storedIpAddress ?? "N/A"))
        Battery: \(Int(batteryLevel * 100))%
        Network: \(networkType)
        Motion: \(motionEmoji) \(motionState) (magnitude: \(String(format: "%.3f", motionMagnitude)))
        App Attest: \(attestEmoji) \(appAttestVerified ? "Verified" : "Not Verified") (Score: \(appAttestScore), Risk: \(appAttestRiskLevel))
        """
    }
}
