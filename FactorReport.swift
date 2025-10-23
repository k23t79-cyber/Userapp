//
//  FactorReport.swift
//  Userapp
//
//  Created by Ri on 10/7/25.
//


//
//  FactorReport.swift
//  Userapp
//
//  Individual factor evaluation result
//

import Foundation

struct FactorReport: Codable {
    let factor: String
    let status: String  // SUCCESS, FAILURE, NEUTRAL
    let scoreImpact: Int
    let reason: String
    
    init(_ factor: String, _ status: String, _ scoreImpact: Int, _ reason: String) {
        self.factor = factor
        self.status = status
        self.scoreImpact = scoreImpact
        self.reason = reason
    }
    
    // Convert to dictionary for Firestore storage
    func toDictionary() -> [String: Any] {
        return [
            "factor": factor,
            "status": status,
            "scoreImpact": scoreImpact,
            "reason": reason
        ]
    }
}