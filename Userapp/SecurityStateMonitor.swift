//
//  SecurityStateMonitor.swift
//  Userapp
//
//  Created by Ri on 8/26/25.
//


import UIKit
import FirebaseAuth
import RealmSwift

extension UIViewController {
    
    // MARK: - Security State Management
    
    /// Check if current user needs security verification and handle accordingly
    func checkAndHandleSecurityVerification() {
        guard let userId = getCurrentUserId() else {
            print("No user ID available for security check")
            return
        }
        
        getCurrentFirebaseToken { [weak self] token in
            TrustScoreManager.shared.shouldTriggerSecurityVerification(for: userId) { needsVerification, trustScore in
                DispatchQueue.main.async {
                    if needsVerification {
                        self?.presentSecurityVerification(userId: userId, firebaseToken: token)
                    } else {
                        print("Trust score acceptable: \(trustScore ?? 0)")
                    }
                }
            }
        }
    }
    
    /// Present security verification modal
    private func presentSecurityVerification(userId: String, firebaseToken: String) {
        // Don't present if already showing
        if presentedViewController is SecurityVerificationViewController {
            return
        }
        
        let verificationVC = SecurityVerificationViewController.create(
            userId: userId,
            firebaseToken: firebaseToken
        )
        
        present(verificationVC, animated: true)
    }
    
    /// Get current user ID from Realm
    private func getCurrentUserId() -> String? {
        return RealmManager.shared.fetchAllUsers().first?.userId
    }
    
    /// Get current Firebase token
    private func getCurrentFirebaseToken(completion: @escaping (String) -> Void) {
        if let currentUser = Auth.auth().currentUser {
            currentUser.getIDToken { token, error in
                completion(token ?? "")
            }
        } else {
            completion("")
        }
    }
}

// MARK: - App State Monitoring
class SecurityStateMonitor {
    static let shared = SecurityStateMonitor()
    private var monitoringTimer: Timer?
    
    private init() {}
    
    /// Start monitoring trust scores periodically
    func startMonitoring() {
        stopMonitoring() // Prevent multiple timers
        
        // Check every 5 minutes (adjust as needed)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.performSecurityCheck()
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func performSecurityCheck() {
        guard let userId = RealmManager.shared.fetchAllUsers().first?.userId else { return }
        
        TrustScoreManager.shared.shouldTriggerSecurityVerification(for: userId) { needsVerification, trustScore in
            if needsVerification {
                DispatchQueue.main.async {
                    self.notifyLowTrustScore(userId: userId, trustScore: trustScore)
                }
            }
        }
    }
    
    private func notifyLowTrustScore(userId: String, trustScore: Double?) {
        // Get the top-most view controller
        guard let topVC = UIApplication.shared.windows.first?.rootViewController?.topMostViewController() else {
            return
        }
        
        // Don't show if already showing verification
        if topVC is SecurityVerificationViewController {
            return
        }
        
        topVC.checkAndHandleSecurityVerification()
    }
}

// MARK: - UIViewController Extension for Top Most VC
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? self
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? self
        }
        
        return self
    }
}

// MARK: - Manual Testing Helper
class SecurityTestHelper {
    /// Manually trigger security verification for testing
    static func triggerSecurityVerification() {
        guard let topVC = UIApplication.shared.windows.first?.rootViewController?.topMostViewController() else {
            return
        }
        
        topVC.checkAndHandleSecurityVerification()
    }
    
    /// Simulate low trust score for testing
    static func simulateLowTrustScore() {
        // You can modify TrustScoreManager to use this flag for testing
        print("Simulating low trust score...")
        triggerSecurityVerification()
    }
}