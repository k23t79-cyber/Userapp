import Foundation
import UIKit
import CoreLocation
import CommonCrypto
import Network
import SystemConfiguration.CaptiveNetwork
import CoreTelephony  // Add this missing import

// MARK: - Complete Trust Signals Data Model for JSON Storage
struct TrustSignalsData: Codable {
    let deviceSignature: String
    let ipAddress: String
    let timezone: String
    let vpnDetected: Bool
    let jailbreakDetected: Bool
    let locationChanged: Bool
    let deviceUptime: Int
    let batteryLevel: Float
    let isCharging: Bool
    let networkType: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let timestamp: Date
    let location: LocationData?
    let individualScores: IndividualScores
    
    struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
        let accuracy: Double
        let timestamp: Date
    }
    
    struct IndividualScores: Codable {
        let deviceSignatureScore: Double
        let ipScore: Double
        let locationScore: Double
        let vpnPenalty: Double
        let jailbreakPenalty: Double
        let uptimeScore: Double
        let networkScore: Double
        let batteryScore: Double
        let totalScore: Double
    }
    
    // Convert to JSON Dictionary for Supabase storage
    func toJSONDict() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(self)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                return jsonObject
            }
        } catch {
            print("❌ Error encoding trust signals to JSON: \(error)")
        }
        
        return [:]
    }
    
    // Create from JSON stored in Supabase
    static func fromJSONDict(_ json: [String: Any]) -> TrustSignalsData? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(TrustSignalsData.self, from: jsonData)
        } catch {
            print("❌ Error decoding trust signals from JSON: \(error)")
            return nil
        }
    }
    
    // Pretty formatted description for debugging
    func debugDescription() -> String {
        return """
        📊 Trust Signals Summary:
        Device: \(deviceModel) (\(osVersion))
        VPN: \(vpnDetected ? "⚠️ Detected" : "✅ Clean")
        Jailbreak: \(jailbreakDetected ? "⚠️ Detected" : "✅ Clean")
        Location: \(locationChanged ? "⚠️ Changed" : "✅ Stable")
        Network: \(networkType)
        Battery: \(batteryLevel * 100)% (\(isCharging ? "Charging" : "Not Charging"))
        Uptime: \(deviceUptime)s
        Final Score: \(individualScores.totalScore)
        """
    }
}

// MARK: - Trust Signals Collector
class TrustSignalsCollector {
    
    static func getCurrentTrustSignals(currentLocation: CLLocation? = nil) -> TrustSignalsData {
        let device = UIDevice.current
        
        // Enable battery monitoring
        device.isBatteryMonitoringEnabled = true
        
        // Collect all trust signals
        let signals = TrustSignalsData(
            deviceSignature: generateDeviceSignature(),
            ipAddress: getCurrentIPAddress(),
            timezone: TimeZone.current.identifier,
            vpnDetected: detectVPN(),
            jailbreakDetected: detectJailbreak(),
            locationChanged: hasLocationChanged(),
            deviceUptime: getDeviceUptime(),
            batteryLevel: device.batteryLevel >= 0 ? device.batteryLevel : 0.5, // Fallback if unavailable
            isCharging: device.batteryState == .charging || device.batteryState == .full,
            networkType: getCurrentNetworkType(),
            appVersion: getAppVersion(),
            osVersion: device.systemVersion,
            deviceModel: device.model,
            timestamp: Date(),
            location: currentLocation != nil ? TrustSignalsData.LocationData(
                latitude: currentLocation!.coordinate.latitude,
                longitude: currentLocation!.coordinate.longitude,
                accuracy: currentLocation!.horizontalAccuracy,
                timestamp: currentLocation!.timestamp
            ) : nil,
            individualScores: calculateIndividualScores(
                vpnDetected: detectVPN(),
                jailbreakDetected: detectJailbreak(),
                locationChanged: hasLocationChanged(),
                batteryLevel: device.batteryLevel
            )
        )
        
        return signals
    }
    
    // MARK: - Individual Signal Collection Methods
    
    private static func generateDeviceSignature() -> String {
        let device = UIDevice.current
        let identifierForVendor = device.identifierForVendor?.uuidString ?? "unknown"
        let systemName = device.systemName
        let systemVersion = device.systemVersion
        let model = device.model
        
        let combined = "\(identifierForVendor)-\(systemName)-\(systemVersion)-\(model)"
        return combined.sha256()
    }
    
    private static func getCurrentIPAddress() -> String {
        // Simplified IP detection - you can enhance this
        var address = ""
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return "unknown" }
        guard let firstAddr = ifaddr else { return "unknown" }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // WiFi interface
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address.isEmpty ? "192.168.1.100" : address
    }
    
    private static func detectVPN() -> Bool {
        // Enhanced VPN detection - FIXED
        guard let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() else {
            return false
        }
        
        // Fix the proxy detection - remove optional chaining
        let proxies = CFNetworkCopyProxiesForURL(URL(string: "http://www.apple.com")! as CFURL, proxySettings).takeRetainedValue()
        
        // Check for VPN indicators
        if let proxyArray = proxies as? [[String: Any]] {
            for proxy in proxyArray {
                if let type = proxy[kCFProxyTypeKey as String] as? String {
                    if type != kCFProxyTypeNone as String {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private static func detectJailbreak() -> Bool {
        // Multiple jailbreak detection methods
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if can write to system directories
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // Should not be able to write here
        } catch {
            // Good, cannot write to system directory
        }
        
        return false
    }
    
    private static func hasLocationChanged() -> Bool {
        // You can implement location change detection logic here
        // This is a placeholder - integrate with your location clustering logic
        return UserDefaults.standard.bool(forKey: "location_recently_changed")
    }
    
    private static func getDeviceUptime() -> Int {
        return Int(ProcessInfo.processInfo.systemUptime)
    }
    
    private static func getCurrentNetworkType() -> String {
        // Enhanced network type detection - FIXED with proper imports
        let networkInfo = CTTelephonyNetworkInfo()
        
        if #available(iOS 12.0, *) {
            if let radioTech = networkInfo.serviceCurrentRadioAccessTechnology?.values.first {
                switch radioTech {
                case CTRadioAccessTechnologyLTE:
                    return "4G/LTE"
                case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA:
                    return "3G"
                case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
                    return "2G"
                default:
                    if #available(iOS 14.1, *) {
                        if radioTech == CTRadioAccessTechnologyNR || radioTech == CTRadioAccessTechnologyNRNSA {
                            return "5G"
                        }
                    }
                    return "Unknown Cellular"
                }
            }
        }
        
        // Default to WiFi if no cellular info
        return "WiFi"
    }
    
    private static func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private static func calculateIndividualScores(
        vpnDetected: Bool,
        jailbreakDetected: Bool,
        locationChanged: Bool,
        batteryLevel: Float
    ) -> TrustSignalsData.IndividualScores {
        
        let deviceSignatureScore: Double = 15.0
        let ipScore: Double = 10.0
        let locationScore: Double = locationChanged ? 5.0 : 15.0
        let vpnPenalty: Double = vpnDetected ? -20.0 : 0.0
        let jailbreakPenalty: Double = jailbreakDetected ? -30.0 : 0.0
        let uptimeScore: Double = 10.0
        let networkScore: Double = 5.0
        let batteryScore: Double = batteryLevel > 0.2 ? 5.0 : -5.0
        
        let totalScore = deviceSignatureScore + ipScore + locationScore +
                        vpnPenalty + jailbreakPenalty + uptimeScore + networkScore + batteryScore
        
        return TrustSignalsData.IndividualScores(
            deviceSignatureScore: deviceSignatureScore,
            ipScore: ipScore,
            locationScore: locationScore,
            vpnPenalty: vpnPenalty,
            jailbreakPenalty: jailbreakPenalty,
            uptimeScore: uptimeScore,
            networkScore: networkScore,
            batteryScore: batteryScore,
            totalScore: max(0, totalScore) // Don't allow negative scores
        )
    }
}

// MARK: - Extensions
extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
