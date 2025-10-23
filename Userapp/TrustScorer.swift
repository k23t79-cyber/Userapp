//
//  TrustScorer.swift
//  Userapp
//
//  Created by Ri on 7/29/25.
//


import Foundation
import CoreLocation

class TrustScorer {
    static func calculateScore(for snapshot: TrustSnapshot) -> Int {
        var score = 100

        if snapshot.isJailbroken { score -= 30 }
        if snapshot.isVPNEnabled { score -= 20 }
       
        // You can add more checks like uptime, timezone, etc.

        return max(0, score)
    }
}
