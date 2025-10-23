import Foundation
import CoreLocation
import RealmSwift
class TrustEvaluator {
    // ✅ CRITICAL: Make this async and use MainActor
    static func evaluate(
        signals: TrustSignals,
        userId: String,
        attributeBaseline: AttributeBaseline?
    ) async -> TrustEvaluationReport {
        
        // ✅ Run everything on MainActor to avoid threading issues
        return await performEvaluation(
            signals: signals,
            userId: userId,
            attributeBaseline: attributeBaseline
        )
    }
    
    // ✅ CRITICAL: All Realm access happens here on MainActor
    @MainActor
    private static func performEvaluation(
        signals: TrustSignals,
        userId: String,
        attributeBaseline: AttributeBaseline?
    ) -> TrustEvaluationReport {
        
        // ========================================
        // PHASE 1: BOT DETECTION
        // ========================================
        print("🤖 PHASE 1: Running bot detection...")
        
        let botReport = BotDetector.shared.detectBot(
            touchInteraction: signals.isUserInteracting,
            motionState: signals.motion,
            motionMagnitude: signals.motionMagnitude
        )
        
        print("   Result: \(botReport.result.description)")
        print("   Reason: \(botReport.reason)")
        
        // ========================================
        // PHASE 2: HARD BLOCK CHECK
        // ========================================
        print("🚨 PHASE 2: Checking hard block conditions...")
        
        if checkHardBlocks(signals: signals, botReport: botReport) {
            let blockReason = getHardBlockReason(signals: signals, botReport: botReport)
            print("🚫 HARD BLOCK TRIGGERED: \(blockReason)")
            
            return TrustEvaluationReport(
                userId: userId,
                totalScore: 0,
                finalStatus: .blocked,
                factors: [
                    TrustFactorReport(
                        "Hard Block",
                        "FAILURE",
                        -100,
                        "🚫 BLOCKED: \(blockReason)"
                    )
                ],
                isHardBlocked: true,
                botDetectionReport: botReport
            )
        }
        
        print("✅ No hard blocks triggered")
        
        // ========================================
        // PHASE 2.5: APP ATTEST (NON-BLOCKING)
        // ========================================
        print("🔐 PHASE 2.5: App Attest verification...")
        
        if signals.appAttestRiskLevel != "unsupported" {
            if !signals.appAttestVerified {
                print("⚠️  WARNING: App Attest verification FAILED")
                print("   - Risk Level: \(signals.appAttestRiskLevel)")
                print("   - Backend Score: \(signals.appAttestScore)")
                print("🧪 TEST MODE: Penalty will be applied in PHASE 3 (continuing...)")
            } else {
                print("✅ App Attest verification PASSED")
                print("   - Risk Level: \(signals.appAttestRiskLevel)")
                print("   - Backend Score: \(signals.appAttestScore)")
            }
        } else {
            print("ℹ️  App Attest not supported on this device")
        }
        
        print("✅ Phase 2.5 complete - proceeding to PHASE 3")
        
        // ========================================
        // PHASE 3: BEHAVIOR-BASED SCORING
        // ========================================
        print("📊 PHASE 3: Evaluating trust factors with behavior-based scoring...")
        
        var score = 0
        var factors: [TrustFactorReport] = []
        let isNewDevice = signals.deviceId != signals.storedDeviceId
        
        // Factor 1: Device Signature (25 points)
        if !isNewDevice {
            score += 25
            factors.append(TrustFactorReport(
                "Device Signature",
                "SUCCESS",
                25,
                "Device matches stored signature"
            ))
        } else {
            factors.append(TrustFactorReport(
                "Device Signature",
                "FAILURE",
                0,
                "New device detected - signature mismatch"
            ))
        }
        
        // Factor 2: Email Match (10 points)
        if signals.email == signals.storedEmail {
            score += 10
            factors.append(TrustFactorReport(
                "Email",
                "SUCCESS",
                10,
                "Email matches stored email"
            ))
        } else {
            factors.append(TrustFactorReport(
                "Email",
                "FAILURE",
                0,
                "Email mismatch detected"
            ))
        }
        
        // Factor 3: Jailbreak Check (10 points / -10 penalty)
        if !signals.isJailbroken {
            score += 10
            factors.append(TrustFactorReport(
                "Jailbreak Check",
                "SUCCESS",
                10,
                "Device is not jailbroken"
            ))
        } else {
            score -= 10
            factors.append(TrustFactorReport(
                "Jailbreak Check",
                "FAILURE",
                -10,
                "⚠️  Device is jailbroken"
            ))
        }
        
        // Factor 4: VPN Status (5 points / -8 penalty)
        if let baseline = attributeBaseline {
            if signals.isVPNEnabled == baseline.normalVPNState {
                score += 5
                factors.append(TrustFactorReport(
                    "VPN",
                    "SUCCESS",
                    5,
                    "VPN state matches baseline (\(baseline.normalVPNState ? "ON" : "OFF"))"
                ))
            } else {
                score -= 8
                let message = signals.isVPNEnabled ? "⚠️  VPN turned ON (baseline: OFF)" : "⚠️  VPN turned OFF (baseline: ON)"
                factors.append(TrustFactorReport(
                    "VPN",
                    "FAILURE",
                    -8,
                    message
                ))
            }
        } else {
            if !signals.isVPNEnabled {
                score += 5
                factors.append(TrustFactorReport(
                    "VPN",
                    "SUCCESS",
                    5,
                    "No VPN detected"
                ))
            } else {
                factors.append(TrustFactorReport(
                    "VPN",
                    "NEUTRAL",
                    0,
                    "VPN active (no baseline to compare)"
                ))
            }
        }
        
        // Factor 5: Uptime Check (5 points / -5 penalty)
        if signals.uptimeMinutes > 120 {
            score += 5
            factors.append(TrustFactorReport(
                "Uptime",
                "SUCCESS",
                5,
                "Device has stable uptime (\(signals.uptimeMinutes) mins)"
            ))
        } else if isNewDevice && signals.uptimeMinutes < 10 {
            score -= 5
            factors.append(TrustFactorReport(
                "Uptime",
                "FAILURE",
                -5,
                "⚠️  New device with very low uptime (<10 mins)"
            ))
        } else {
            factors.append(TrustFactorReport(
                "Uptime",
                "NEUTRAL",
                0,
                "Uptime moderate, no impact"
            ))
        }
        
        // Factor 6: BOT DETECTION (20 points)
        let botScore = botReport.scoreContribution
        score += botScore
        
        let botStatus = botReport.result.isBot ? "FAILURE" :
        (botReport.result.isSuspicious ? "WARNING" : "SUCCESS")
        
        factors.append(TrustFactorReport(
            "Bot Detection",
            botStatus,
            botScore,
            botReport.reason
        ))
        
        print("   🤖 Bot Detection: +\(botScore) points - \(botReport.result.description)")
        
        // Factor 7: APP ATTEST (20 points possible: -20 to +10)
        let attestScore = evaluateAppAttest(signals: signals)
        score += attestScore.pointsAwarded
        if attestScore.pointsAwarded < 0 {
            factors.append(TrustFactorReport(
                "App Attest",
                "FAILURE",
                attestScore.pointsAwarded,
                attestScore.reason
            ))
        } else if attestScore.pointsAwarded > 0 {
            factors.append(TrustFactorReport(
                "App Attest",
                "SUCCESS",
                attestScore.pointsAwarded,
                attestScore.reason
            ))
        } else {
            factors.append(TrustFactorReport(
                "App Attest",
                "NEUTRAL",
                0,
                attestScore.reason
            ))
        }
        
        print("   🔐 App Attest: \(attestScore.pointsAwarded >= 0 ? "+\(attestScore.pointsAwarded)" : "\(attestScore.pointsAwarded)") points - \(attestScore.reason)")
        
        // Factor 8: LOCATION CLUSTERING (15 points / -20 penalty)
        // ✅ Thread-safe: already on MainActor
        let locationResult = evaluateLocationClustering(
            signals: signals,
            userId: userId
        )
        score += locationResult.points
        factors.append(TrustFactorReport(
            "Location Clustering",
            locationResult.points > 0 ? "SUCCESS" : "FAILURE",
            locationResult.points,
            locationResult.reason
        ))
        
        print("   🗺️  Location: \(locationResult.points >= 0 ? "+\(locationResult.points)" : "\(locationResult.points)") points - \(locationResult.reason)")
        
        // Factor 9: Network Type (5 points / -3 penalty)
        if let baseline = attributeBaseline {
            if signals.networkType == baseline.normalNetworkType {
                score += 5
                factors.append(TrustFactorReport(
                    "Network",
                    "SUCCESS",
                    5,
                    "Network type matches baseline (\(baseline.normalNetworkType))"
                ))
            } else {
                score -= 3
                factors.append(TrustFactorReport(
                    "Network",
                    "FAILURE",
                    -3,
                    "⚠️  Network changed: \(baseline.normalNetworkType) → \(signals.networkType)"
                ))
            }
        } else {
            factors.append(TrustFactorReport(
                "Network",
                "NEUTRAL",
                0,
                "Network: \(signals.networkType) (no baseline)"
            ))
        }
        
        // Factor 10: Timezone (10 points / -15 penalty)
        if let baseline = attributeBaseline {
            if signals.timezone == baseline.normalTimezone {
                score += 10
                factors.append(TrustFactorReport(
                    "Timezone",
                    "SUCCESS",
                    10,
                    "Timezone matches baseline (\(baseline.normalTimezone))"
                ))
            } else {
                score -= 15
                factors.append(TrustFactorReport(
                    "Timezone",
                    "FAILURE",
                    -15,
                    "🚨 CRITICAL: Timezone changed (\(baseline.normalTimezone) → \(signals.timezone))"
                ))
            }
        } else {
            factors.append(TrustFactorReport(
                "Timezone",
                "NEUTRAL",
                0,
                "Timezone: \(signals.timezone) (no baseline)"
            ))
        }
        
        // Factor 11: IP Address (5 points / -10 penalty)
        if let baseline = attributeBaseline {
            if baseline.isKnownIP(signals.ipAddress) {
                score += 5
                factors.append(TrustFactorReport(
                    "IP Address",
                    "SUCCESS",
                    5,
                    "IP in known range"
                ))
            } else {
                score -= 10
                factors.append(TrustFactorReport(
                    "IP Address",
                    "FAILURE",
                    -10,
                    "⚠️  New IP detected: \(signals.ipAddress)"
                ))
            }
        } else {
            factors.append(TrustFactorReport(
                "IP Address",
                "NEUTRAL",
                0,
                "IP: \(signals.ipAddress) (no baseline)"
            ))
        }
        
        // Factor 12: Login Time Pattern (5 points / -5 penalty)
        let currentHour = Calendar.current.component(.hour, from: Date())
        if let baseline = attributeBaseline {
            if currentHour >= baseline.normalLoginHoursStart && currentHour <= baseline.normalLoginHoursEnd {
                score += 5
                factors.append(TrustFactorReport(
                    "Login Time",
                    "SUCCESS",
                    5,
                    "Normal login hours (\(baseline.normalLoginHoursStart):00-\(baseline.normalLoginHoursEnd):00)"
                ))
            } else {
                score -= 5
                factors.append(TrustFactorReport(
                    "Login Time",
                    "FAILURE",
                    -5,
                    "⚠️  Unusual time: \(currentHour):00 (normal: \(baseline.normalLoginHoursStart):00-\(baseline.normalLoginHoursEnd):00)"
                ))
            }
        } else {
            factors.append(TrustFactorReport(
                "Login Time",
                "NEUTRAL",
                0,
                "Login time: \(currentHour):00 (no baseline)"
            ))
        }
        
        // ========================================
        // PHASE 4: DETERMINE FINAL STATUS
        // ========================================
        let status: TrustEvaluationStatus
        if score >= 70 {
            status = .trusted
            print("✅ FINAL STATUS: TRUSTED (Score: \(score)/135)")
        } else if score >= 45 {
            status = .reverifyIdentity
            print("⚠️  FINAL STATUS: REVERIFY_IDENTITY (Score: \(score)/135)")
        } else {
            status = .blocked
            print("🚫 FINAL STATUS: BLOCKED (Score: \(score)/135 - Score too low)")
        }
        
        return TrustEvaluationReport(
            userId: userId,
            totalScore: score,
            finalStatus: status,
            factors: factors,
            isHardBlocked: false,
            botDetectionReport: botReport
        )
    }
    
    // ✅ Thread-safe location evaluation (runs on MainActor)
    private static func evaluateLocationClustering(
        signals: TrustSignals,
        userId: String
    ) -> (points: Int, reason: String) {
        
        guard let locationString = signals.location,
              let location = parseLocation(locationString) else {
            return (-10, "⚠️  No location available")
        }
        
        // Use TrustManager to check if location is in a trusted cluster
        let isInTrustedCluster = TrustManager.shared.evaluateLocationTrust(currentLocation: location)
        
        if isInTrustedCluster {
            return (15, "✅ Within trusted location cluster (3+ visits, 45+ min)")
        }
        
        // Find nearest cluster
        guard let nearestCluster = findNearestCluster(location: location, userId: userId) else {
            return (-15, "⚠️  No location clusters established yet")
        }
        
        let distance = location.distance(from: CLLocation(
            latitude: nearestCluster.centerLatitude,
            longitude: nearestCluster.centerLongitude
        ))
        
        // Distance-based scoring
        if distance < 1000 {
            return (-2, "Near trusted area (\(Int(distance))m away) - learning phase")
        } else if distance < 5000 {
            return (-5, "⚠️  \(Int(distance/1000))km from trusted area")
        } else if distance < 50000 {
            return (-10, "⚠️  \(Int(distance/1000))km from any trusted area")
        } else if distance < 500000 {
            return (-15, "⚠️  Different city detected")
        } else {
            return (-20, "🚨 CRITICAL: Different country/region detected")
        }
    }
    
    private static func parseLocation(_ locationString: String) -> CLLocation? {
        let components = locationString.split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    private static func findNearestCluster(location: CLLocation, userId: String) -> LocationClusterObject? {
        do {
            let realm = try Realm()
            let clusters = realm.objects(LocationClusterObject.self)
            
            var nearest: LocationClusterObject?
            var minDistance = Double.infinity
            
            for cluster in clusters {
                let clusterLoc = CLLocation(
                    latitude: cluster.centerLatitude,
                    longitude: cluster.centerLongitude
                )
                let distance = location.distance(from: clusterLoc)
                
                if distance < minDistance {
                    minDistance = distance
                    nearest = cluster
                }
            }
            
            return nearest
        } catch {
            print("❌ Error finding nearest cluster: \(error)")
            return nil
        }
    }
    
    // MARK: - App Attest Evaluation
    
    private static func evaluateAppAttest(signals: TrustSignals) -> (pointsAwarded: Int, reason: String) {
        
        var pointsAwarded = 0
        var reason = ""
        
        if signals.appAttestRiskLevel == "unsupported" {
            return (0, "App Attest not supported on this device")
        }
        
        switch signals.appAttestRiskLevel.lowercased() {
        case "low":
            if signals.appAttestVerified {
                pointsAwarded = 10
                reason = "✅ App integrity verified (low risk, score: \(signals.appAttestScore))"
            } else {
                pointsAwarded = -10
                reason = "⚠️  TEST MODE: App Attest failed (low risk, would normally block)"
            }
            
        case "medium":
            pointsAwarded = -15
            reason = "⚠️  TEST MODE: App integrity medium risk (score: \(signals.appAttestScore))"
            
        case "high":
            pointsAwarded = -20
            reason = "⚠️  TEST MODE: App integrity high risk (score: \(signals.appAttestScore))"
            
        case "unknown":
            pointsAwarded = -15
            reason = "⚠️  TEST MODE: App Attest verification failed (unknown status)"
            
        default:
            pointsAwarded = -10
            reason = "⚠️  TEST MODE: App Attest unknown status"
        }
        
        if signals.appAttestScore > 0 && signals.appAttestScore < 60 {
            pointsAwarded = min(pointsAwarded, -15)
            reason = "⚠️  TEST MODE: App integrity score below threshold (\(signals.appAttestScore)/100)"
        }
        
        print("   🧪 TEST MODE: App Attest applied \(pointsAwarded) point penalty (not blocking)")
        
        return (pointsAwarded, reason)
    }
    
    // MARK: - Hard Block Conditions
    
    static func checkHardBlocks(signals: TrustSignals, botReport: BotDetectionReport) -> Bool {
        let isBot = botReport.result.isBot
        let isSuspicious = botReport.result.isSuspicious
        let isJailbroken = signals.isJailbroken
        let isNewDevice = signals.deviceId != signals.storedDeviceId
        let isVPN = signals.isVPNEnabled
        let lowUptime = signals.uptimeMinutes < 5
        let timezoneMismatch = signals.timezone != signals.storedTimezone
        let ipMismatch = signals.ipAddress != signals.storedIpAddress
        let emailMismatch = signals.email != signals.storedEmail
        let noMotion = signals.motion == .unknown
        
        let appAttestSupported = signals.appAttestRiskLevel != "unsupported"
        let appAttestMediumRisk = signals.appAttestRiskLevel == "medium"
        let appAttestLowScore = signals.appAttestScore > 0 && signals.appAttestScore < 50
        
        // Hard block scenarios
        if isBot && isJailbroken && isNewDevice {
            print("🚫 HARD BLOCK #1: Bot + Jailbroken + New Device")
            return true
        }
        
        if isBot && isVPN && isNewDevice && lowUptime {
            print("🚫 HARD BLOCK #2: Bot + VPN + New Device + Low Uptime")
            return true
        }
        
        if isJailbroken && isNewDevice {
            print("🚫 HARD BLOCK #3: Jailbroken + New Device")
            return true
        }
        
        if isBot && isNewDevice && ipMismatch && timezoneMismatch && emailMismatch {
            print("🚫 HARD BLOCK #4: Bot + Multiple Anomalies")
            return true
        }
        
        if isBot && noMotion && isJailbroken {
            print("🚫 HARD BLOCK #5: Bot + No Gyroscope + Jailbroken")
            return true
        }
        
        if isBot && noMotion && isVPN && isNewDevice {
            print("🚫 HARD BLOCK #6: Bot + No Gyroscope + VPN + New Device")
            return true
        }
        
        if isSuspicious && isJailbroken && isNewDevice {
            print("🚫 HARD BLOCK #7: Suspicious Bot + Jailbroken + New Device")
            return true
        }
        
        if appAttestSupported && isBot && appAttestMediumRisk && isJailbroken {
            print("🚫 HARD BLOCK #8: Bot + App Attest Medium Risk + Jailbroken")
            return true
        }
        
        if appAttestSupported && isBot && appAttestMediumRisk && isVPN && isNewDevice {
            print("🚫 HARD BLOCK #9: Bot + App Attest Medium Risk + VPN + New Device")
            return true
        }
        
        if appAttestSupported && appAttestLowScore && isJailbroken && isNewDevice {
            print("🚫 HARD BLOCK #10: Low App Integrity + Jailbroken + New Device")
            return true
        }
        
        if appAttestSupported && appAttestMediumRisk && isJailbroken && isVPN {
            print("🚫 HARD BLOCK #11: Medium Risk App Attest + Jailbroken + VPN")
            return true
        }
        
        if appAttestSupported && isBot && appAttestLowScore && isVPN {
            print("🚫 HARD BLOCK #12: Bot + Low App Attest Score + VPN")
            return true
        }
        
        return false
    }
    
    private static func getHardBlockReason(signals: TrustSignals, botReport: BotDetectionReport) -> String {
        let isBot = botReport.result.isBot
        let isSuspicious = botReport.result.isSuspicious
        let isJailbroken = signals.isJailbroken
        let isNewDevice = signals.deviceId != signals.storedDeviceId
        let isVPN = signals.isVPNEnabled
        let lowUptime = signals.uptimeMinutes < 5
        let noMotion = signals.motion == .unknown
        
        let appAttestMediumRisk = signals.appAttestRiskLevel == "medium"
        let appAttestLowScore = signals.appAttestScore > 0 && signals.appAttestScore < 50
        
        var reasons: [String] = []
        
        if isBot { reasons.append("Bot detected") }
        if isSuspicious { reasons.append("Suspicious behavior") }
        if isJailbroken { reasons.append("Jailbroken device") }
        if isNewDevice { reasons.append("New device") }
        if isVPN { reasons.append("VPN active") }
        if lowUptime { reasons.append("Low uptime") }
        if noMotion { reasons.append("No gyroscope") }
        if appAttestMediumRisk { reasons.append("App Attest medium risk") }
        if appAttestLowScore { reasons.append("Low integrity score (\(signals.appAttestScore))") }
        
        return reasons.joined(separator: " + ")
    }
}
