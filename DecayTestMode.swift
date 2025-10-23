//
//  DecayTestMode.swift
//  Userapp
//
//  Created by Ri on 10/15/25.
//


//
//  TrustDecayManager+TestMode.swift
//  Userapp
//
//  TEST MODE: Short intervals for decay testing
//

import Foundation

// MARK: - Test Mode Configuration

struct DecayTestMode {
    // ⚠️ SET TO TRUE FOR TESTING, FALSE FOR PRODUCTION
    static let isEnabled = true  // ✅ Turn ON for testing
    
    // TEST MODE: Time intervals in MINUTES
    static let testIntervals = TestIntervals(
        criticalInactivePeriod: 120,  // 2 hours = Warning/Removal
        recoveryResetThreshold: 30,   // 30 minutes = Reset decay
        dailyCheckInterval: 60        // 1 hour = 1 "day" equivalent
    )
    
    // PRODUCTION MODE: Time intervals in DAYS
    static let productionIntervals = ProductionIntervals(
        criticalInactiveDays: 15,     // 15 days = Removal
        recoveryResetDays: 7,         // 7 days = Reset
        dailyCheckInterval: 1         // 1 day
    )
    
    struct TestIntervals {
        let criticalInactivePeriod: Int  // minutes
        let recoveryResetThreshold: Int  // minutes
        let dailyCheckInterval: Int      // minutes
    }
    
    struct ProductionIntervals {
        let criticalInactiveDays: Int
        let recoveryResetDays: Int
        let dailyCheckInterval: Int
    }
}
