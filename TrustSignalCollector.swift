import Foundation
import UIKit
import SystemConfiguration

final class TrustSignalCollector {
    static let shared = TrustSignalCollector()
    
    private init() {}
    
    /// Collect all trust signals including motion data and App Attest
    /// ✅ MODIFIED: Now async to support App Attest verification
    func collectSignals(userId: String, baseline: TrustBaseline?, completion: @escaping (TrustSignals) -> Void) {
        print("📊 Collecting trust signals dynamically...")
        
        // ✅ FIX: Extract baseline data immediately on main thread if it exists
        let baselineEmail: String?
        let baselineDeviceId: String?
        let baselineTimezone: String?
        let baselineSystemVersion: String?
        
        if let baseline = baseline {
            // Extract data synchronously before any async operations
            baselineEmail = baseline.email
            baselineDeviceId = baseline.deviceId
            baselineTimezone = baseline.timezone
            baselineSystemVersion = baseline.systemVersion
        } else {
            baselineEmail = nil
            baselineDeviceId = nil
            baselineTimezone = nil
            baselineSystemVersion = nil
        }
        
        // ✅ Start gyroscope monitoring if not already started
        GyroscopeManager.shared.startMonitoring()
        
        // ✅ Get motion state
        var motionState = GyroscopeManager.shared.getCurrentMotionState()
        var motionMagnitude = 0.0
        
        // If motion is unknown, try to get a fresh reading
        if motionState == .unknown {
            let semaphore = DispatchSemaphore(value: 0)
            
            GyroscopeManager.shared.captureMotionSnapshot(duration: 0.5) { state, magnitude in
                motionState = state
                motionMagnitude = magnitude
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 1.0)
        } else {
            let metrics = GyroscopeManager.shared.getMotionMetrics()
            motionMagnitude = metrics["magnitude"] as? Double ?? 0.0
        }
        
        // Collect device and network info
        let deviceId = getDeviceId()
        let systemVersion = UIDevice.current.systemVersion
        let timezone = TimeZone.current.identifier
        let batteryLevel = UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.5
        
        // Security checks
        let isJailbroken = checkJailbreak()
        let isVPNEnabled = checkVPN()
        
        // User interaction (default to true if no monitor available)
        let isUserInteracting = true
        
        // System info
        let uptimeSeconds = getSystemUptime()
        
        // Network info
        let ipAddress = getIPAddress()
        let networkType = getNetworkType()
        
        // Location info
        let location = getLocation()
        let locationVisitCount = 0 // Default value
        
        // ✅ NEW: Collect App Attest signal (async)
        print("🔒 Collecting App Attest signal...")
        collectAppAttestSignal(userId: userId) { attestResult in
            
            print("✅ App Attest signal collected")
            print("   - Valid: \(attestResult.isValid)")
            print("   - Score: \(attestResult.score)")
            print("   - Risk: \(attestResult.riskLevel)")
            
            // ✅ FIX: Use extracted baseline data instead of accessing baseline object
            let signals = TrustSignals(
                deviceId: deviceId,
                email: baselineEmail ?? "unknown@example.com",
                isJailbroken: isJailbroken,
                isVPNEnabled: isVPNEnabled,
                isUserInteracting: isUserInteracting,
                uptimeSeconds: uptimeSeconds,
                timezone: timezone,
                ipAddress: ipAddress,
                location: location,
                timestamp: Date(),
                batteryLevel: batteryLevel,
                systemVersion: systemVersion,
                networkType: networkType,
                motionState: motionState.rawValue,
                motionMagnitude: motionMagnitude,
                appAttestVerified: attestResult.isValid,
                appAttestScore: attestResult.score,
                appAttestRiskLevel: attestResult.riskLevel,
                appAttestKeyId: attestResult.keyId,
                storedDeviceId: baselineDeviceId,
                storedEmail: baselineEmail,
                storedTimezone: baselineTimezone,
                storedIpAddress: nil,
                storedLocation: nil,
                storedSystemVersion: baselineSystemVersion,
                storedNetworkType: nil,
                locationVisitCount: locationVisitCount,
                userId: userId
            )
            
            print("  ✅ Signals collected: \(signals.toDictionary().keys.joined(separator: ", "))")
            print("  📱 Motion State: \(motionState.rawValue)")
            if motionState != .unknown {
                print("  📊 Motion Magnitude: \(String(format: "%.3f", motionMagnitude)) rad/s")
            }
            print("  🔒 App Attest: \(attestResult.isValid ? "✅ Verified" : "⚠️ Failed")")
            
            completion(signals)
        }
    }
    /// ✅ NEW: Collect App Attest verification signal
    private func collectAppAttestSignal(userId: String, completion: @escaping (AppAttestResult) -> Void) {
        print("🔐 TRUST COLLECTOR: Collecting App Attest signals...")
        
        // Use the simplified API - just one method call
        AppAttestManager.shared.performAttestation(userId: userId) { result in
            switch result {
            case .success(let attestResult):
                print("✅ TRUST COLLECTOR: App Attest completed")
                print("   - Valid: \(attestResult.isValid)")
                print("   - Score: \(attestResult.score)")
                print("   - Risk: \(attestResult.riskLevel)")
                completion(attestResult)
                
            case .failure(let error):
                print("❌ TRUST COLLECTOR: App Attest failed - \(error.localizedDescription)")
                // Return default failed result
                let failedResult = AppAttestResult(
                    isValid: false,
                    score: 0,
                    riskLevel: "unknown",
                    keyId: "",
                    token: nil,
                    error: error.localizedDescription,
                    attestationObject: nil,
                    certificateChain: [],
                    clientDataHash: "",
                    processingTime: 0
                )
                completion(failedResult)
            }
        }
    }
    
    /// Collect signals asynchronously (better for UI responsiveness)
    func collectSignalsAsync(userId: String, baseline: TrustBaseline?, completion: @escaping (TrustSignals) -> Void) {
        // Already async due to App Attest, just call directly
        collectSignals(userId: userId, baseline: baseline, completion: completion)
    }
    
    /// Collect signals and calculate trust score
    func collectAndEvaluate(userId: String, baseline: TrustBaseline?, completion: @escaping ((signals: TrustSignals, score: Int)) -> Void) {
        collectSignals(userId: userId, baseline: baseline) { signals in
            let score = self.calculateTrustScore(from: signals, baseline: baseline)
            completion((signals, score))
        }
    }
    
    // MARK: - Trust Score Calculation
    
    /// Calculate trust score from signals (0-110, with App Attest bonus)
    private func calculateTrustScore(from signals: TrustSignals, baseline: TrustBaseline?) -> Int {
        var score = 0
        
        // Security checks (30 points)
        if !signals.isJailbroken { score += 15 }
        if !signals.isVPNEnabled { score += 15 }
        
        // User interaction (10 points)
        if signals.isUserInteracting { score += 10 }
        
        // Battery level (5 points)
        if signals.batteryLevel > 0.2 { score += 5 }
        
        // Network (5 points)
        if !signals.ipAddress.isEmpty && signals.networkType != "Unknown" {
            score += 5
        }
        
        // System uptime (5 points) - penalize very short uptimes
        if signals.uptimeSeconds > 300 { score += 5 } // More than 5 minutes
        
        // ✅ Motion State (10 points)
        score += getMotionScore(from: signals)
        
        // ✅ NEW: App Attest (up to 10 bonus points)
        score += getAppAttestScore(from: signals)
        
        // Baseline comparison (30 points)
        if let baseline = baseline {
            score += compareWithBaseline(signals, baseline: baseline)
        } else {
            score += 15 // No baseline yet, give neutral score
        }
        
        return min(score, 110) // Cap at 110 with App Attest bonus
    }
    
    // ✅ Motion-based scoring
    private func getMotionScore(from signals: TrustSignals) -> Int {
        switch signals.motion {
        case .still:
            // Device is still - high trust (8/10 points)
            return 8
        case .moving:
            // Device is moving - moderate trust (6/10 points)
            return 6
        case .unknown:
            // No motion data - neutral (5/10 points)
            return 5
        }
    }
    
    // ✅ NEW: App Attest scoring
    private func getAppAttestScore(from signals: TrustSignals) -> Int {
        // If unsupported, no penalty
        if signals.appAttestRiskLevel == "unsupported" {
            return 0
        }
        
        // Evaluate based on risk level
        switch signals.appAttestRiskLevel.lowercased() {
        case "low":
            if signals.appAttestVerified {
                return 10 // Bonus points for valid attestation
            } else {
                return 0 // Neutral
            }
        case "medium":
            return -5 // Penalty
        case "high":
            return -10 // Major penalty
        default:
            return 0
        }
    }
    
    private func compareWithBaseline(_ signals: TrustSignals, baseline: TrustBaseline) -> Int {
        var baselineScore = 0
        
        // Device match (10 points)
        if signals.deviceId == baseline.deviceId {
            baselineScore += 10
        }
        
        // System version match (5 points)
        if signals.systemVersion == baseline.systemVersion {
            baselineScore += 5
        }
        
        // Timezone match (10 points)
        if signals.timezone == baseline.timezone {
            baselineScore += 10
        }
        
        // Location consistency (5 points)
        if signals.locationVisitCount > 0 {
            baselineScore += 5
        }
        
        return baselineScore
    }
    
    // MARK: - Helper Methods (Fallbacks for missing utilities)
    
    private func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
    
    private func checkJailbreak() -> Bool {
        // Check if JailbreakDetector exists, otherwise use fallback
        #if targetEnvironment(simulator)
        return false
        #else
        // Basic jailbreak check
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if can write to system
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
    
    private func checkVPN() -> Bool {
        // Check if VPNDetector exists, otherwise use fallback
        guard let cfDict = CFNetworkCopySystemProxySettings()?.takeUnretainedValue() as? [String: Any] else {
            return false
        }
        
        let keys = cfDict.keys
        return keys.contains("__SCOPED__")
    }
    
    private func getSystemUptime() -> Int {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        
        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let uptime = Date().timeIntervalSince1970 - Double(boottime.tv_sec)
            return Int(uptime)
        }
        
        return ProcessInfo.processInfo.systemUptime.rounded(.down) |> Int.init
    }
    
    private func getIPAddress() -> String {
        var address: String = "Unknown"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return address }
        guard let firstAddr = ifaddr else { return address }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    private func getNetworkType() -> String {
        let reachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com")
        var flags = SCNetworkReachabilityFlags()
        
        guard let reach = reachability, SCNetworkReachabilityGetFlags(reach, &flags) else {
            return "Unknown"
        }
        
        let isReachable = flags.contains(.reachable)
        let isWWAN = flags.contains(.isWWAN)
        
        if isReachable {
            if isWWAN {
                return "Cellular"
            } else {
                return "WiFi"
            }
        }
        
        return "No Connection"
    }
    
    private func getLocation() -> String? {
        // Return nil if LocationManager doesn't have current location
        // You can integrate with your LocationManager if available
        return nil
    }
}

// MARK: - Operator for Int conversion
infix operator |> : MultiplicationPrecedence
func |> <T, U>(value: T, function: (T) -> U) -> U {
    return function(value)
}

