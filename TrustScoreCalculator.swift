import Foundation

struct TrustScoreCalculator {
    
    // NEW: Compare current signals with baseline and calculate score
    static func calculateWithComparison(
        currentSignals: [String: Any],
        baselineSignals: [String: Any]?
    ) -> (score: Int, details: [String: Any]) {
        
        // If no baseline exists, this is first login - return neutral score
        guard let baseline = baselineSignals else {
            return (score: 100, details: ["reason": "first_login", "baseline_created": true])
        }
        
        var score = 0
        var scoreDetails: [String: Any] = [:]
        
        // 1. Device ID Match (20 points)
        if let currentDeviceId = currentSignals["deviceId"] as? String,
           let baselineDeviceId = baseline["deviceId"] as? String {
            if currentDeviceId == baselineDeviceId {
                score += 20
                scoreDetails["device_match"] = true
            } else {
                scoreDetails["device_match"] = false
                scoreDetails["device_changed"] = true
            }
        }
        
        // 2. Timezone Match (10 points)
        if let currentTZ = currentSignals["timezone"] as? String,
           let baselineTZ = baseline["timezone"] as? String {
            if currentTZ == baselineTZ {
                score += 10
                scoreDetails["timezone_match"] = true
            } else {
                scoreDetails["timezone_match"] = false
            }
        }
        
        // 3. System Version Similarity (10 points)
        // Allow minor version differences
        if let currentVersion = currentSignals["systemVersion"] as? String,
           let baselineVersion = baseline["systemVersion"] as? String {
            let currentMajor = currentVersion.split(separator: ".").first
            let baselineMajor = baselineVersion.split(separator: ".").first
            if currentMajor == baselineMajor {
                score += 10
                scoreDetails["system_version_compatible"] = true
            } else {
                scoreDetails["system_version_compatible"] = false
            }
        }
        
        // 4. Jailbreak Status (20 points - must not be jailbroken)
        if let isJailbroken = currentSignals["isJailbroken"] as? Bool {
            if !isJailbroken {
                score += 20
                scoreDetails["jailbreak_status"] = "clean"
            } else {
                scoreDetails["jailbreak_status"] = "detected"
                scoreDetails["security_risk"] = true
            }
        }
        
        // 5. VPN Status (20 points - VPN disabled preferred)
        if let isVPNEnabled = currentSignals["isVPNEnabled"] as? Bool {
            if !isVPNEnabled {
                score += 20
                scoreDetails["vpn_status"] = "disabled"
            } else {
                scoreDetails["vpn_status"] = "enabled"
                score += 10 // Partial credit - VPN not always malicious
            }
        }
        
        // 6. Device Uptime (10 points - reasonable uptime)
        if let uptime = currentSignals["uptimeSeconds"] as? Int {
            if uptime >= 60 { // At least 1 minute uptime
                score += 10
                scoreDetails["uptime_reasonable"] = true
            } else {
                scoreDetails["uptime_reasonable"] = false
                scoreDetails["recently_rebooted"] = true
            }
        }
        
        // 7. Battery Level Pattern (10 points - not critical but adds context)
        // This is more for behavioral pattern than validation
        if let currentBattery = currentSignals["batteryLevel"] as? Float,
           let baselineBattery = baseline["batteryLevel"] as? Float {
            // Just check if battery is in reasonable range (not critical for scoring)
            if currentBattery >= 0.0 && currentBattery <= 1.0 {
                score += 10
                scoreDetails["battery_reading_valid"] = true
            }
        }
        
        // Ensure score is within 0-100 range
        score = min(max(score, 0), 100)
        scoreDetails["final_score"] = score
        
        return (score: score, details: scoreDetails)
    }
    
    // DEPRECATED: Old method for backward compatibility
    static func calculate(isJailbroken: Bool, isVPNEnabled: Bool, isUserInteracting: Bool, uptime: Int) -> Int {
        var score = 100
        
        if isJailbroken { score -= 40 }
        if isVPNEnabled { score -= 20 }
        if !isUserInteracting { score -= 10 }
        if uptime < 60 { score -= 10 }

        return max(score, 0)
    }
}
