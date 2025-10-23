//
//  JailbreakDetector.swift
//  Userapp
//
//  Enhanced jailbreak detection with comprehensive checks
//

import Foundation
import UIKit
import MachO

class JailbreakDetector {
    
    // Legacy simple check (kept for backward compatibility)
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let jailbreakPaths = ["/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib", "/bin/bash"]
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        return false
        #endif
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // 🔐 PHASE 2 THREAD 3: Comprehensive Security Checks
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    func performComprehensiveCheck() -> JailbreakDetectionResult {
        #if targetEnvironment(simulator)
        print("🧵 THREAD 3: Running in simulator - skipping jailbreak checks")
        return JailbreakDetectionResult(
            detected: false,
            fileSystemTestsPassed: true,
            suspiciousProcesses: [],
            dynamicLibrariesClean: true,
            codeInjectionDetected: false,
            confidenceLevel: 100
        )
        #else
        
        var suspiciousItems: [String] = []
        var confidenceScore = 100
        
        // Test 1: File System Checks
        let fileSystemPassed = checkFileSystem(&suspiciousItems, &confidenceScore)
        
        // Test 2: Dynamic Library Analysis
        let libraryCheckPassed = checkDynamicLibraries(&suspiciousItems, &confidenceScore)
        
        // Test 3: Code Injection Detection
        let codeInjectionDetected = checkCodeInjection(&suspiciousItems, &confidenceScore)
        
        // Test 4: URL Scheme Detection
        let urlSchemeCheckPassed = checkURLSchemes(&suspiciousItems, &confidenceScore)
        
        // Test 5: System Integrity Checks
        let systemIntegrityPassed = checkSystemIntegrity(&suspiciousItems, &confidenceScore)
        
        let jailbroken = !fileSystemPassed || !libraryCheckPassed ||
                         codeInjectionDetected || !urlSchemeCheckPassed || !systemIntegrityPassed
        
        return JailbreakDetectionResult(
            detected: jailbroken,
            fileSystemTestsPassed: fileSystemPassed,
            suspiciousProcesses: suspiciousItems,
            dynamicLibrariesClean: libraryCheckPassed,
            codeInjectionDetected: codeInjectionDetected,
            confidenceLevel: max(0, min(100, confidenceScore))
        )
        #endif
    }
    
    // MARK: - File System Checks
    
    private func checkFileSystem(_ suspiciousItems: inout [String], _ confidenceScore: inout Int) -> Bool {
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/blackra1n.app",
            "/Applications/FakeCarrier.app",
            "/Applications/Icy.app",
            "/Applications/IntelliScreen.app",
            "/Applications/MxTube.app",
            "/Applications/RockApp.app",
            "/Applications/SBSettings.app",
            "/Applications/WinterBoard.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/",
            "/usr/libexec/cydia/",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/private/var/mobile/Library/SBSettings/Themes",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/usr/libexec/sftp-server",
            "/usr/bin/sshd",
            "/usr/libexec/ssh-keysign",
            "/bin/sh",
            "/etc/ssh/sshd_config",
            "/usr/share/jailbreak/injectme.plist"
        ]
        
        var foundSuspicious = false
        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                suspiciousItems.append("File: \(path)")
                confidenceScore -= 15
                foundSuspicious = true
            }
        }
        
        // Check if can write to system directories
        let testPath = "/private/jailbreak_test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            suspiciousItems.append("Write access to /private/")
            confidenceScore -= 20
            foundSuspicious = true
        } catch {
            // Expected behavior - cannot write to system directories
        }
        
        // Check symbolic links
        if let _ = try? FileManager.default.destinationOfSymbolicLink(atPath: "/Applications") {
            suspiciousItems.append("Symbolic link: /Applications")
            confidenceScore -= 10
            foundSuspicious = true
        }
        
        return !foundSuspicious
    }
    
    // MARK: - Dynamic Library Checks
    
    private func checkDynamicLibraries(_ suspiciousItems: inout [String], _ confidenceScore: inout Int) -> Bool {
        let suspiciousLibraries = [
            "SubstrateLoader.dylib",
            "SSLKillSwitch.dylib",
            "SSLKillSwitch2.dylib",
            "MobileSubstrate.dylib",
            "TweakInject.dylib",
            "CydiaSubstrate",
            "cynject",
            "CustomWidgetIcons",
            "PreferenceLoader",
            "RocketBootstrap",
            "WeeLoader",
            "/.file", // Hidden file indicator
            "SubstrateInserter.dylib",
            "SubstrateBootstrap.dylib",
            "ABypass",
            "FlyJB",
            "Liberty",
            "Shadow"
        ]
        
        var foundSuspicious = false
        
        // Use _dyld functions safely
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let imageName = _dyld_get_image_name(i) {
                let name = String(cString: imageName)
                for suspiciousLib in suspiciousLibraries {
                    if name.lowercased().contains(suspiciousLib.lowercased()) {
                        suspiciousItems.append("Library: \(suspiciousLib)")
                        confidenceScore -= 10
                        foundSuspicious = true
                    }
                }
            }
        }
        return !foundSuspicious
    }
    
    // MARK: - Code Injection Detection
    
    private func checkCodeInjection(_ suspiciousItems: inout [String], _ confidenceScore: inout Int) -> Bool {
        // Check for environment variables used by injection tools
        let suspiciousEnvVars = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_PRINT_TO_FILE",
            "DYLD_PRINT_ENV",
            "DYLD_PRINT_LIBRARIES",
            "_MSSafeMode",
            "_SafeMode"
        ]
        
        for envVar in suspiciousEnvVars {
            if let value = getenv(envVar) {
                suspiciousItems.append("Env: \(envVar)=\(String(cString: value))")
                confidenceScore -= 15
                return true
            }
        }
        return false
    }
    
    // MARK: - URL Scheme Checks
    
    private func checkURLSchemes(_ suspiciousItems: inout [String], _ confidenceScore: inout Int) -> Bool {
        let suspiciousSchemes = [
            "cydia://package/com.example.package",
            "undecimus://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://",
            "taurine://",
            "checkra1n://"
        ]
        
        var foundSuspicious = false
        for scheme in suspiciousSchemes {
            if let url = URL(string: scheme) {
                let canOpen = UIApplication.shared.canOpenURL(url)
                if canOpen {
                    suspiciousItems.append("URL Scheme: \(scheme)")
                    confidenceScore -= 10
                    foundSuspicious = true
                }
            }
        }
        return !foundSuspicious
    }
    
    // MARK: - System Integrity Checks
    
    private func checkSystemIntegrity(_ suspiciousItems: inout [String], _ confidenceScore: inout Int) -> Bool {
        var integrityPassed = true
        
        // Check for stat discrepancies
        var statInfo = stat()
        let statResult = stat("/Applications", &statInfo)
        if statResult == 0 {
            if statInfo.st_mode & S_IWOTH != 0 {
                suspiciousItems.append("System: /Applications is world-writable")
                confidenceScore -= 15
                integrityPassed = false
            }
        }
        
        // Check if /etc/fstab exists (shouldn't on iOS)
        if FileManager.default.fileExists(atPath: "/etc/fstab") {
            suspiciousItems.append("File: /etc/fstab exists")
            confidenceScore -= 10
            integrityPassed = false
        }
        
        return integrityPassed
    }
}

// MARK: - Result Structure

struct JailbreakDetectionResult {
    let detected: Bool
    let fileSystemTestsPassed: Bool
    let suspiciousProcesses: [String]
    let dynamicLibrariesClean: Bool
    let codeInjectionDetected: Bool
    let confidenceLevel: Int
}
