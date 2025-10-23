//
//  TrustDecayManager.swift
//  Userapp
//
//  Progressive decay manager with TEST MODE support
//

import Foundation
import RealmSwift

// MARK: - Shared Enums


enum UserStatusResult {
    case `continue`(newScore: Int, consecutiveActiveDays: Int, decayApplied: Int, recoveryGained: Int)
    case continueWithReset(newScore: Int, message: String)
    case removeDevice(deviceId: String, reason: String)
    case promoteSecondary(oldPrimaryDeviceId: String, reason: String)
    case warning(message: String, minutesUntilRemoval: Int)  // ✅ NEW: Warning state
}

// MARK: - Trust Decay Manager

class TrustDecayManager {
    
    static let shared = TrustDecayManager()
    
    // MARK: - Dynamic Constants (Test vs Production)
    
    private var CRITICAL_INACTIVE_THRESHOLD: Int {
        if DecayTestMode.isEnabled {
            return DecayTestMode.testIntervals.criticalInactivePeriod  // 2 hours
        } else {
            return DecayTestMode.productionIntervals.criticalInactiveDays  // 15 days
        }
    }
    
    private var RECOVERY_RESET_THRESHOLD: Int {
        if DecayTestMode.isEnabled {
            return DecayTestMode.testIntervals.recoveryResetThreshold  // 30 minutes
        } else {
            return DecayTestMode.productionIntervals.recoveryResetDays  // 7 days
        }
    }
    
    private var DAILY_CHECK_INTERVAL: Int {
        if DecayTestMode.isEnabled {
            return DecayTestMode.testIntervals.dailyCheckInterval  // 60 minutes = 1 "day"
        } else {
            return DecayTestMode.productionIntervals.dailyCheckInterval  // 1 day
        }
    }
    
    // Step-based decay tiers (scale based on mode)
    private var decayTiers: [(maxUnits: Int, decayRate: Double)] {
        if DecayTestMode.isEnabled {
            // TEST MODE: Units in "hours" (60 min intervals)
            return [
                (1, 1.5),    // 0-1 hour: 1.5 points/hour
                (2, 2.0),    // 1-2 hours: 2.0 points/hour
                (3, 3.0),    // 2-3 hours: 3.0 points/hour
                (24, 5.0)    // 3+ hours: 5.0 points/hour
            ]
        } else {
            // PRODUCTION MODE: Units in days
            return [
                (3, 1.5),    // 0-3 days: 1.5 points/day
                (7, 2.0),    // 4-7 days: 2.0 points/day
                (14, 3.0),   // 8-14 days: 3.0 points/day
                (365, 5.0)   // 15+ days: 5.0 points/day
            ]
        }
    }
    
    private init() {
        if DecayTestMode.isEnabled {
            print("⚠️ DECAY MANAGER: TEST MODE ENABLED")
            print("   🕐 1 hour = 1 day")
            print("   ⚠️ 2 hours inactive = Warning/Removal")
            print("   🔄 30 min active = Reset")
        }
    }
    
    // MARK: - Main Evaluation Method
    
    func evaluateUserStatus(
        userId: String,
        deviceId: String,
        deviceType: DeviceType,
        previousScore: Int,
        lastLoginDate: Date,
        consecutiveActiveDays: Int,
        currentDate: Date = Date()
    ) -> UserStatusResult {
        
        // Calculate time difference
        let timeInterval = currentDate.timeIntervalSince(lastLoginDate)
        
        let (timeUnits, timeUnitName) = getTimeUnits(from: timeInterval)
        
        print("📊 DECAY EVALUATION (\(deviceType.rawValue)):")
        print("   🕐 Mode: \(DecayTestMode.isEnabled ? "TEST (1hr=1day)" : "PRODUCTION")")
        print("   - Device: \(String(deviceId.prefix(8)))...")
        print("   - Time since last login: \(timeUnits) \(timeUnitName)")
        print("   - Previous score: \(previousScore)")
        print("   - Consecutive active periods: \(consecutiveActiveDays)")
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // CRITICAL CHECK: Maximum inactive threshold
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        if timeUnits >= CRITICAL_INACTIVE_THRESHOLD {
            print("🚫 CRITICAL: Device inactive for \(timeUnits) \(timeUnitName)")
            
            if deviceType == .primary {
                print("   → PRIMARY device inactive - PROMOTING SECONDARY to PRIMARY")
                return .promoteSecondary(
                    oldPrimaryDeviceId: deviceId,
                    reason: "Primary device inactive for \(timeUnits) \(timeUnitName) - promoting most active secondary"
                )
            } else {
                print("   → SECONDARY device inactive - REMOVING this device only")
                return .removeDevice(
                    deviceId: deviceId,
                    reason: "Secondary device inactive for \(timeUnits) \(timeUnitName)"
                )
            }
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // WARNING CHECK: 75% of critical threshold
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        let warningThreshold = Int(Double(CRITICAL_INACTIVE_THRESHOLD) * 0.75)
        
        if timeUnits >= warningThreshold {
            let remainingTime = CRITICAL_INACTIVE_THRESHOLD - timeUnits
            print("⚠️ WARNING: Device approaching removal threshold")
            print("   - Current: \(timeUnits) \(timeUnitName)")
            print("   - Removal at: \(CRITICAL_INACTIVE_THRESHOLD) \(timeUnitName)")
            print("   - Time remaining: \(remainingTime) \(timeUnitName)")
            
            // Still calculate decay and continue
            let decayAmount = calculateDecay(for: timeUnits)
            let newScore = max(0, previousScore - decayAmount)
            
            return .warning(
                message: "⚠️ Your account will be affected in \(remainingTime) \(timeUnitName) due to inactivity",
                minutesUntilRemoval: remainingTime
            )
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // SCENARIO 1: Active within check interval
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        if timeUnits <= 1 {
            let newConsecutiveActiveDays = consecutiveActiveDays + 1
            var newScore = previousScore
            var recoveryGained = 0
            
            // Apply recovery (+1 point per check interval)
            if newScore < 100 {
                recoveryGained = 1
                newScore = min(100, previousScore + recoveryGained)
            }
            
            print("✅ Active user (within check interval)")
            print("   - Recovery: +\(recoveryGained) points")
            print("   - New score: \(newScore)")
            print("   - Consecutive active periods: \(newConsecutiveActiveDays)")
            
            // Check if decay counter should be reset
            if newConsecutiveActiveDays >= RECOVERY_RESET_THRESHOLD {
                print("🔄 RESET: User active for \(newConsecutiveActiveDays) continuous periods")
                print("   → Decay counter RESET to 0")
                return .continueWithReset(
                    newScore: newScore,
                    message: "Excellent engagement! Trust fully restored."
                )
            }
            
            return .continue(
                newScore: newScore,
                consecutiveActiveDays: newConsecutiveActiveDays,
                decayApplied: 0,
                recoveryGained: recoveryGained
            )
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // SCENARIO 2: Gap detected (inactive)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        print("⚠️ Gap detected: \(timeUnits) \(timeUnitName) inactive")
        
        // Calculate decay
        let decayAmount = calculateDecay(for: timeUnits)
        let newScore = max(0, previousScore - decayAmount)
        
        print("   - Decay applied: -\(decayAmount) points")
        print("   - New score: \(newScore)")
        print("   - Consecutive active periods reset to: 0")
        
        return .continue(
            newScore: newScore,
            consecutiveActiveDays: 0,
            decayApplied: decayAmount,
            recoveryGained: 0
        )
    }
    
    // MARK: - Time Conversion
    
    /// Convert seconds to appropriate time units based on mode
    private func getTimeUnits(from timeInterval: TimeInterval) -> (units: Int, unitName: String) {
        if DecayTestMode.isEnabled {
            // TEST MODE: Convert to "hours" (60-minute blocks)
            let hours = Int(timeInterval / 3600)
            return (hours, hours == 1 ? "hour" : "hours")
        } else {
            // PRODUCTION MODE: Convert to days
            let days = Int(timeInterval / 86400)
            return (days, days == 1 ? "day" : "days")
        }
    }
    
    // MARK: - Decay Calculation
    
    private func calculateDecay(for timeUnits: Int) -> Int {
        var totalDecay = 0
        
        if timeUnits <= decayTiers[0].maxUnits {
            totalDecay = Int(Double(timeUnits) * decayTiers[0].decayRate)
        } else if timeUnits <= decayTiers[1].maxUnits {
            let tier1 = Int(Double(decayTiers[0].maxUnits) * decayTiers[0].decayRate)
            let tier2 = Int(Double(timeUnits - decayTiers[0].maxUnits) * decayTiers[1].decayRate)
            totalDecay = tier1 + tier2
        } else if timeUnits <= decayTiers[2].maxUnits {
            let tier1 = Int(Double(decayTiers[0].maxUnits) * decayTiers[0].decayRate)
            let tier2 = Int(Double(decayTiers[1].maxUnits - decayTiers[0].maxUnits) * decayTiers[1].decayRate)
            let tier3 = Int(Double(timeUnits - decayTiers[1].maxUnits) * decayTiers[2].decayRate)
            totalDecay = tier1 + tier2 + tier3
        } else {
            let tier1 = Int(Double(decayTiers[0].maxUnits) * decayTiers[0].decayRate)
            let tier2 = Int(Double(decayTiers[1].maxUnits - decayTiers[0].maxUnits) * decayTiers[1].decayRate)
            let tier3 = Int(Double(decayTiers[2].maxUnits - decayTiers[1].maxUnits) * decayTiers[2].decayRate)
            let tier4 = Int(Double(timeUnits - decayTiers[2].maxUnits) * decayTiers[3].decayRate)
            totalDecay = tier1 + tier2 + tier3 + tier4
        }
        
        let unitName = DecayTestMode.isEnabled ? "hours" : "days"
        print("   📉 Decay breakdown for \(timeUnits) \(unitName):")
        print("      Total decay: \(totalDecay) points")
        
        return totalDecay
    }
}
