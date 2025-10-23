//
//  JailbreakChecker.swift
//  Userapp
//
//  Created by Ri on 7/29/25.
//


import Foundation

struct JailbreakChecker {
    static func isDeviceJailbroken() -> Bool {
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
}
