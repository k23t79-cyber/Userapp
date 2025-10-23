import Foundation
import NetworkExtension
import SystemConfiguration

class VPNChecker {
    static let shared = VPNChecker()
    
    private init() {}
    
    func isVPNConnected() -> Bool {
        // Method 1: Check NEVPNManager (requires proper entitlements)
        if isVPNConnectedViaNEVPN() {
            return true
        }
        
        // Method 2: Check network interfaces
        if isVPNConnectedViaNetworkInterface() {
            return true
        }
        
        // Method 3: Check system configuration
        return isVPNConnectedViaSystemConfiguration()
    }
    
    private func isVPNConnectedViaNEVPN() -> Bool {
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        NEVPNManager.shared().loadFromPreferences { error in
            if error == nil {
                isConnected = NEVPNManager.shared().connection.status == .connected
            }
            semaphore.signal()
        }
        
        // Wait for async call to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 2.0)
        return isConnected
    }
    
    private func isVPNConnectedViaNetworkInterface() -> Bool {
        guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
            return false
        }
        
        for interface in interfaces {
            if interface.contains("tap") || interface.contains("tun") || interface.contains("ppp") || interface.contains("ipsec") {
                return true
            }
        }
        
        return false
    }
    
    private func isVPNConnectedViaSystemConfiguration() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else {
            return false
        }
        
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        
        // Check for proxy settings that might indicate VPN
        if let httpProxy = nsDict["HTTPProxy"] as? String, !httpProxy.isEmpty {
            return true
        }
        
        if let httpsProxy = nsDict["HTTPSProxy"] as? String, !httpsProxy.isEmpty {
            return true
        }
        
        return false
    }
    
    // Alternative method using route checking
    func isVPNConnectedViaRoutes() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return false
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: interface.ifa_name)
                
                // Check for common VPN interface names
                if name.contains("tun") || name.contains("tap") || name.contains("ppp") || name.contains("ipsec") || name.contains("utun") {
                    return true
                }
            }
            
            ptr = interface.ifa_next
        }
        
        return false
    }
}
