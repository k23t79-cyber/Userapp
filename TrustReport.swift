//
//  TrustReport.swift
//  Userapp
//
//  Trust evaluation result models (No conflicts)
//

import Foundation

// MARK: - Trust Evaluation Status
enum TrustEvaluationStatus: String, Codable {
    case trusted = "TRUSTED"
    case reverifyIdentity = "REVERIFY_IDENTITY"
    case blocked = "BLOCKED"
}

// MARK: - Trust Evaluation Report
struct TrustEvaluationReport {
    let userId: String
    let totalScore: Int
    let finalStatus: TrustEvaluationStatus
    let factors: [TrustFactorReport]
    let isHardBlocked: Bool
    let botDetectionReport: BotDetectionReport?
    let timestamp: Date
    
    init(
        userId: String,
        totalScore: Int,
        finalStatus: TrustEvaluationStatus,
        factors: [TrustFactorReport],
        isHardBlocked: Bool,
        botDetectionReport: BotDetectionReport? = nil
    ) {
        self.userId = userId
        self.totalScore = totalScore
        self.finalStatus = finalStatus
        self.factors = factors
        self.isHardBlocked = isHardBlocked
        self.botDetectionReport = botDetectionReport
        self.timestamp = Date()
    }
    
    /// Check if user should be allowed access
    var shouldAllowAccess: Bool {
        return finalStatus == .trusted && !isHardBlocked
    }
    
    /// Check if user should be prompted for reverification
    var requiresReverification: Bool {
        return finalStatus == .reverifyIdentity ||
               (botDetectionReport?.result.isSuspicious ?? false)
    }
    
    /// Check if user should be blocked
    var shouldBlock: Bool {
        return finalStatus == .blocked || isHardBlocked
    }
    
    /// Get summary for logging
    func summary() -> String {
        var summary = """
        📊 Trust Report Summary:
        User: \(userId)
        Score: \(totalScore)/100
        Status: \(finalStatus.rawValue)
        Hard Blocked: \(isHardBlocked)
        """
        
        if let botReport = botDetectionReport {
            summary += "\n🤖 Bot Detection: \(botReport.result.description)"
        }
        
        return summary
    }
}

// MARK: - Trust Factor Report
struct TrustFactorReport {
    let factor: String
    let status: String  // "SUCCESS", "FAILURE", "NEUTRAL", "WARNING"
    let scoreImpact: Int
    let reason: String
    
    init(_ factor: String, _ status: String, _ scoreImpact: Int, _ reason: String) {
        self.factor = factor
        self.status = status
        self.scoreImpact = scoreImpact
        self.reason = reason
    }
    
    var emoji: String {
        switch status {
        case "SUCCESS": return "✅"
        case "FAILURE": return "❌"
        case "WARNING": return "⚠️"
        case "NEUTRAL": return "➖"
        default: return "❓"
        }
    }
    
    func description() -> String {
        return "\(emoji) \(factor): \(reason) (\(scoreImpact > 0 ? "+" : "")\(scoreImpact) points)"
    }
}
