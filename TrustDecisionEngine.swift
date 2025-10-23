//
//  TrustDecisionEngine.swift
//  Userapp
//
//  Navigation decision logic (separate from evaluation)
//

import Foundation
import UIKit

class TrustDecisionEngine {
    static let shared = TrustDecisionEngine()
    
    private init() {}
    
    // MARK: - Decision Types (Separate from TrustEvaluationReport)
    
    enum DecisionStatus: String {  // ✅ Added String raw value
        case trusted = "TRUSTED"
        case reverifyIdentity = "REVERIFY_IDENTITY"
        case blocked = "BLOCKED"
    }
    
    struct TrustDecision {
        let status: DecisionStatus
        let score: Int
        let reasons: [String]
        let nextAction: NavigationAction
    }
    
    enum NavigationAction {
        case allowAccess           // Navigate to Home
        case requireReverification // Navigate to SecurityQuestionVerify
        case blockAccess          // Show error, logout
        case setupSecurity        // Navigate to SecurityQuestionSetup
    }
    
    // MARK: - Decision Making
    
    /// Evaluate trust score and determine next action (Matching Android logic)
    func evaluateTrust(score: Int, isJailbroken: Bool, isVPNEnabled: Bool, deviceType: DeviceType) -> TrustDecision {
        print("⚖️ TRUST DECISION ENGINE: Evaluating trust")
        print("   - Score: \(score)")
        print("   - Jailbroken: \(isJailbroken)")
        print("   - VPN: \(isVPNEnabled)")
        print("   - Device Type: \(deviceType.rawValue)")
        
        var reasons: [String] = []
        
        // Critical security issues (immediate block)
        if isJailbroken {
            reasons.append("Device is jailbroken")
            print("🚫 DECISION: BLOCKED - Jailbroken device detected")
            return TrustDecision(
                status: .blocked,
                score: score,
                reasons: reasons,
                nextAction: .blockAccess
            )
        }
        
        // Android matching logic: score >= 60 = TRUSTED
        if score >= 60 {
            if deviceType == .secondary {
                // Secondary devices always need verification first
                reasons.append("Secondary device requires verification")
                print("⚠️ DECISION: REVERIFY - Secondary device detected")
                return TrustDecision(
                    status: .reverifyIdentity,
                    score: score,
                    reasons: reasons,
                    nextAction: .requireReverification
                )
            }
            
            reasons.append("All trust checks passed")
            print("✅ DECISION: TRUSTED - Access granted")
            return TrustDecision(
                status: .trusted,
                score: score,
                reasons: reasons,
                nextAction: .allowAccess
            )
        }
        
        // Android matching logic: score 40-59 = REVERIFY_IDENTITY
        if score >= 40 {
            if isVPNEnabled {
                reasons.append("VPN detected")
            }
            reasons.append("Trust score below threshold")
            print("⚠️ DECISION: REVERIFY_IDENTITY - Low trust score")
            return TrustDecision(
                status: .reverifyIdentity,
                score: score,
                reasons: reasons,
                nextAction: .requireReverification
            )
        }
        
        // Android matching logic: score < 40 = BLOCKED
        reasons.append("Trust score critically low")
        print("🚫 DECISION: BLOCKED - Trust score too low")
        return TrustDecision(
            status: .blocked,
            score: score,
            reasons: reasons,
            nextAction: .blockAccess
        )
    }
    
    /// Quick trust check for existing sessions
    func quickTrustCheck(snapshot: TrustSnapshot) -> Bool {
        return snapshot.trustLevel >= 60 && !snapshot.isJailbroken
    }
}
