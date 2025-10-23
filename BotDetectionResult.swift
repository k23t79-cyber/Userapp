//
//  BotDetectionResult.swift
//  Userapp
//
//  Created by Ri on 10/13/25.
//


//
//  BotDetector.swift
//  Userapp
//
//  Strict bot detection combining touch interaction + gyroscope motion
//

import Foundation

// MARK: - Bot Detection Result
enum BotDetectionResult {
    case human(confidence: Double)           // High confidence human (0.85-1.0)
    case suspicious(confidence: Double)      // Suspicious activity (0.40-0.84)
    case bot(confidence: Double)             // High confidence bot (0.0-0.39)
    case unknown                             // Cannot determine
    
    var isBot: Bool {
        switch self {
        case .bot:
            return true
        default:
            return false
        }
    }
    
    var isSuspicious: Bool {
        switch self {
        case .suspicious, .bot:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .human(let confidence):
            return "Human (confidence: \(String(format: "%.0f", confidence * 100))%)"
        case .suspicious(let confidence):
            return "Suspicious (confidence: \(String(format: "%.0f", confidence * 100))%)"
        case .bot(let confidence):
            return "Bot (confidence: \(String(format: "%.0f", (1.0 - confidence) * 100))%)"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Bot Detection Report
struct BotDetectionReport {
    let result: BotDetectionResult
    let touchInteraction: Bool
    let motionState: MotionState
    let motionMagnitude: Double
    let reason: String
    let timestamp: Date
    
    /// Score contribution (0-20 points based on confidence)
    var scoreContribution: Int {
        switch result {
        case .human(let confidence):
            return Int(20 * confidence)  // 17-20 points
        case .suspicious(let confidence):
            return Int(20 * confidence)  // 8-16 points
        case .bot(let confidence):
            return Int(20 * confidence)  // 0-7 points
        case .unknown:
            return 5  // Neutral (25% of 20)
        }
    }
}

// MARK: - Bot Detector (Strict Security Mode)
final class BotDetector {
    
    static let shared = BotDetector()
    
    private init() {}
    
    // MARK: - Main Detection Method
    
    /// Detect bot using STRICT security rules (Touch + Gyroscope)
    /// - Parameters:
    ///   - touchInteraction: User touch detected
    ///   - motionState: Gyroscope motion state
    ///   - motionMagnitude: Gyroscope rotation magnitude
    /// - Returns: Bot detection report with confidence score
    func detectBot(
        touchInteraction: Bool,
        motionState: MotionState,
        motionMagnitude: Double = 0.0
    ) -> BotDetectionReport {
        
        print("🤖 BOT DETECTOR: Analyzing behavioral signals...")
        print("   👆 Touch: \(touchInteraction)")
        print("   📱 Motion: \(motionState.rawValue)")
        print("   📊 Magnitude: \(String(format: "%.3f", motionMagnitude))")
        
        let result: BotDetectionResult
        let reason: String
        
        // ========================================
        // STRICT SECURITY RULES (Bot Detection)
        // ========================================
        
        // 🔴 Rule 1: NO TOUCH + NO MOTION = DEFINITE BOT
        if !touchInteraction && motionState == .unknown {
            result = .bot(confidence: 0.05)  // 5% human confidence = 95% bot
            reason = "No touch interaction + No gyroscope data = Automated script"
            print("   🚫 VERDICT: BOT (No touch + No motion)")
        }
        
        // 🔴 Rule 2: NO TOUCH + STILL DEVICE = HIGH CONFIDENCE BOT
        else if !touchInteraction && motionState == .still {
            result = .bot(confidence: 0.10)  // 10% human confidence = 90% bot
            reason = "No touch interaction + Still device = Bot on stationary device"
            print("   🚫 VERDICT: BOT (No touch + Still)")
        }
        
        // 🟡 Rule 3: NO TOUCH + MOVING = SUSPICIOUS
        // Could be legitimate (auto-login while walking) but suspicious
        else if !touchInteraction && motionState == .moving {
            result = .suspicious(confidence: 0.40)  // 40% human confidence
            reason = "No touch but device moving = Possible auto-login or bot with motion simulation"
            print("   ⚠️ VERDICT: SUSPICIOUS (No touch but moving)")
        }
        
        // 🟡 Rule 4: TOUCH + UNKNOWN GYROSCOPE = SUSPICIOUS
        // Could be simulator, no permission, or gyroscope unavailable
        else if touchInteraction && motionState == .unknown {
            result = .suspicious(confidence: 0.50)  // 50% human confidence
            reason = "Touch detected but no gyroscope = Simulator, no permission, or unavailable sensor"
            print("   ⚠️ VERDICT: SUSPICIOUS (Touch but no gyro)")
        }
        
        // ✅ Rule 5: TOUCH + STILL = HUMAN
        // Normal use case: user sitting at desk, phone on table
        else if touchInteraction && motionState == .still {
            result = .human(confidence: 0.90)  // 90% human confidence
            reason = "Touch interaction + Still device = Normal stationary use"
            print("   ✅ VERDICT: HUMAN (Touch + Still)")
        }
        
        // ✅ Rule 6: TOUCH + MOVING = HIGH CONFIDENCE HUMAN
        // Best case: natural human behavior with device motion
        else if touchInteraction && motionState == .moving {
            result = .human(confidence: 0.95)  // 95% human confidence
            reason = "Touch interaction + Device motion = Natural human behavior"
            print("   ✅ VERDICT: HUMAN (Touch + Moving)")
        }
        
        // ❓ Fallback: Unknown state
        else {
            result = .unknown
            reason = "Unable to determine bot status from available signals"
            print("   ❓ VERDICT: UNKNOWN")
        }
        
        return BotDetectionReport(
            result: result,
            touchInteraction: touchInteraction,
            motionState: motionState,
            motionMagnitude: motionMagnitude,
            reason: reason,
            timestamp: Date()
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Quick bot check (returns boolean)
    func isBot(touchInteraction: Bool, motionState: MotionState) -> Bool {
        let report = detectBot(
            touchInteraction: touchInteraction,
            motionState: motionState
        )
        return report.result.isBot
    }
    
    /// Quick suspicious check (returns boolean)
    func isSuspicious(touchInteraction: Bool, motionState: MotionState) -> Bool {
        let report = detectBot(
            touchInteraction: touchInteraction,
            motionState: motionState
        )
        return report.result.isSuspicious
    }
    
    /// Get bot confidence (0.0 = definite bot, 1.0 = definite human)
    func getBotConfidence(touchInteraction: Bool, motionState: MotionState) -> Double {
        let report = detectBot(
            touchInteraction: touchInteraction,
            motionState: motionState
        )
        
        switch report.result {
        case .human(let confidence):
            return confidence
        case .suspicious(let confidence):
            return confidence
        case .bot(let confidence):
            return confidence
        case .unknown:
            return 0.5  // Neutral
        }
    }
    
    // MARK: - Trust Scoring
    
    /// Calculate trust score contribution from bot detection (0-20 points)
    func getTrustScoreContribution(
        touchInteraction: Bool,
        motionState: MotionState
    ) -> Int {
        let report = detectBot(
            touchInteraction: touchInteraction,
            motionState: motionState
        )
        return report.scoreContribution
    }
    
    /// Get detailed trust assessment
    func getTrustAssessment(
        touchInteraction: Bool,
        motionState: MotionState
    ) -> String {
        let report = detectBot(
            touchInteraction: touchInteraction,
            motionState: motionState
        )
        return report.reason
    }
}
