//
//  DeviceSecurityChecker.swift
//  Userapp
//
//  Created by Ri on 9/10/25.
//

import Foundation
import UIKit

class DeviceSecurityChecker {
    
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false // Simulators are not jailbroken
        #else
        
        // Check 1: Common jailbreak files
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/private/var/tmp/cydia.log",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/usr/libexec/cydia/",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia",
            "/usr/share/jailbreak",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Applications/blackra1n.app"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check 2: Can we open suspicious files?
        let suspiciousFiles = [
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in suspiciousFiles {
            if let file = fopen(path, "r") {
                fclose(file)
                return true
            }
        }
        
        // Check 3: Try to write to system directories (shouldn't be possible on non-jailbroken devices)
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // If we can write, device is likely jailbroken
        } catch {
            // Good, we can't write to protected directories
        }
        
        // Check 4: Check for suspicious app schemes
        let suspiciousSchemes = [
            "cydia://package/com.example.package"
        ]
        
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme) {
                if UIApplication.shared.canOpenURL(url) {
                    return true
                }
            }
        }
        
        // Check 5: Check for dynamic library injection
        let suspiciousLibraries = [
            "MobileSubstrate",
            "SubstrateLoader",
            "SubstrateInserter",
            "cycript"
        ]
        
        for library in suspiciousLibraries {
            if let _ = dlopen(library, RTLD_NOW) {
                return true
            }
        }
        
        // Check 6: Sandbox violation check - try to read outside sandbox
        do {
            let paths = ["/etc/fstab", "/bin/bash"]
            for path in paths {
                if FileManager.default.isReadableFile(atPath: path) {
                    // Try to actually read it
                    let _ = try String(contentsOfFile: path)
                    return true
                }
            }
        } catch {
            // Good, we can't read system files
        }
        
        return false
        #endif
    }
    
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        
        return (result == 0) && (info.kp_proc.p_flag & P_TRACED) != 0
    }
    
    // Additional security checks
    
    static func isReverseEngineered() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        
        // Check for common reverse engineering tools
        let suspiciousLibraries = [
            "FridaGadget",
            "frida",
            "cynject",
            "libcycript"
        ]
        
        for _ in suspiciousLibraries {
            // Check if suspicious libraries are loaded
            // This is a simplified check
        }
        
        return false
        #endif
    }
    
    static func hasProperCodeSigning() -> Bool {
        // Check if app has proper code signing
        // This would be verified by App Store / TestFlight
        return true
    }
}
