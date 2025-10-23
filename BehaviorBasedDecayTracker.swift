//
//  BehaviorBasedDecayTracker.swift
//  Userapp
//

import Foundation
import RealmSwift
import CoreLocation

class BehaviorBasedDecayTracker {
    
    static let shared = BehaviorBasedDecayTracker()
    private init() {}
    
    // ═══════════════════════════════════════════
    // Main Decay Tracking Function
    // ✅ CHANGED: Returns DecaySnapshotResult (plain struct)
    // ═══════════════════════════════════════════
    
    func trackDecay(
        userId: String,
        deviceId: String,
        previousScore: Int,
        currentScore: Int,
        factors: [TrustFactorReport]
    ) async -> DecaySnapshotResult {
        
        let decayAmount = previousScore - currentScore
        
        print("\n📉 BEHAVIOR-BASED DECAY TRACKING")
        print("=" + String(repeating: "=", count: 60))
        print("   Previous Trust Score: \(previousScore)")
        print("   Current Trust Score: \(currentScore)")
        print("   Decay Amount: \(decayAmount) points")
        
        // Break down decay by factor
        var locationDecay = 0
        var vpnDecay = 0
        var networkDecay = 0
        var timezoneDecay = 0
        var ipDecay = 0
        var loginTimeDecay = 0
        var jailbreakDecay = 0
        
        for trustFactor in factors {
            if trustFactor.scoreImpact < 0 {
                switch trustFactor.factor {
                case "Location Clustering":
                    locationDecay = trustFactor.scoreImpact
                case "VPN":
                    vpnDecay = trustFactor.scoreImpact
                case "Network":
                    networkDecay = trustFactor.scoreImpact
                case "Timezone":
                    timezoneDecay = trustFactor.scoreImpact
                case "IP Address":
                    ipDecay = trustFactor.scoreImpact
                case "Login Time":
                    loginTimeDecay = trustFactor.scoreImpact
                case "Jailbreak Check":
                    jailbreakDecay = trustFactor.scoreImpact
                default:
                    break
                }
            }
        }
        
        print("\n   📊 Decay Breakdown:")
        if locationDecay < 0 { print("      🗺️  Location: \(locationDecay)") }
        if vpnDecay < 0 { print("      🔒 VPN: \(vpnDecay)") }
        if networkDecay < 0 { print("      📶 Network: \(networkDecay)") }
        if timezoneDecay < 0 { print("      🌍 Timezone: \(timezoneDecay)") }
        if ipDecay < 0 { print("      🌐 IP: \(ipDecay)") }
        if loginTimeDecay < 0 { print("      ⏰ Login Time: \(loginTimeDecay)") }
        if jailbreakDecay < 0 { print("      ⚠️  Jailbreak: \(jailbreakDecay)") }
        
        if decayAmount == 0 {
            print("   ✅ No decay - behavior is normal")
        }
        
        // Determine severity
        let severity = getDecaySeverity(decayAmount: decayAmount)
        print("   ⚠️  Decay Severity: \(severity.rawValue)")
        print("=" + String(repeating: "=", count: 60))
        
        // ✅ Save to Realm (async, no return value needed)
        await saveDecaySnapshot(
            userId: userId,
            deviceId: deviceId,
            previousScore: previousScore,
            currentScore: currentScore,
            decayAmount: decayAmount,
            locationDecay: locationDecay,
            vpnDecay: vpnDecay,
            networkDecay: networkDecay,
            timezoneDecay: timezoneDecay,
            ipDecay: ipDecay,
            loginTimeDecay: loginTimeDecay,
            jailbreakDecay: jailbreakDecay,
            severity: severity.rawValue
        )
        
        // ✅ Return plain struct (thread-safe)
        return DecaySnapshotResult(
            decayAmount: decayAmount,
            severity: severity.rawValue,
            previousScore: previousScore,
            currentScore: currentScore,
            locationDecay: locationDecay,
            vpnDecay: vpnDecay,
            networkDecay: networkDecay,
            timezoneDecay: timezoneDecay,
            ipDecay: ipDecay,
            loginTimeDecay: loginTimeDecay,
            jailbreakDecay: jailbreakDecay
        )
    }
    
    // ═══════════════════════════════════════════
    // Severity Classification
    // ═══════════════════════════════════════════
    
    private func getDecaySeverity(decayAmount: Int) -> DecaySeverity {
        if decayAmount >= 50 {
            return .critical
        } else if decayAmount >= 30 {
            return .high
        } else if decayAmount >= 15 {
            return .medium
        } else if decayAmount >= 5 {
            return .low
        } else if decayAmount > 0 {
            return .minimal
        } else {
            return .none
        }
    }
    
    // ═══════════════════════════════════════════
    // Persistence (Thread-Safe) - Fire and Forget
    // ═══════════════════════════════════════════
    
    private func saveDecaySnapshot(
        userId: String,
        deviceId: String,
        previousScore: Int,
        currentScore: Int,
        decayAmount: Int,
        locationDecay: Int,
        vpnDecay: Int,
        networkDecay: Int,
        timezoneDecay: Int,
        ipDecay: Int,
        loginTimeDecay: Int,
        jailbreakDecay: Int,
        severity: String
    ) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                
                let snapshot = DecaySnapshot()
                snapshot.userId = userId
                snapshot.deviceId = deviceId
                snapshot.timestamp = Date()
                snapshot.previousScore = previousScore
                snapshot.currentScore = currentScore
                snapshot.decayAmount = decayAmount
                snapshot.locationDecay = locationDecay
                snapshot.vpnDecay = vpnDecay
                snapshot.networkDecay = networkDecay
                snapshot.timezoneDecay = timezoneDecay
                snapshot.ipDecay = ipDecay
                snapshot.loginTimeDecay = loginTimeDecay
                snapshot.jailbreakDecay = jailbreakDecay
                snapshot.severity = severity
                
                try realm.write {
                    realm.add(snapshot)
                }
                
                print("💾 Decay snapshot saved to Realm")
                
            } catch {
                print("❌ Error saving decay snapshot: \(error)")
            }
        }.value
    }
}

// ═══════════════════════════════════════════
// Decay Severity Enum
// ═══════════════════════════════════════════

enum DecaySeverity: String {
    case none = "None"
    case minimal = "Minimal"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}
