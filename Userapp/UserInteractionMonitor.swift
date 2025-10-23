//
//  UserInteractionMonitor.swift
//  Userapp
//
//  Created by Ri on 10/13/25.
//


//
//  UserInteractionMonitor.swift
//  Userapp
//
//  Simple user interaction tracker
//

import UIKit

final class UserInteractionMonitor {
    static let shared = UserInteractionMonitor()
    
    private(set) var isUserInteracting: Bool = false
    private var lastInteractionTime: Date?
    private let interactionTimeout: TimeInterval = 5.0 // 5 seconds
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Monitor touch events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidInteract),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Swizzle touch events (simple approach)
        DispatchQueue.main.async {
            self.isUserInteracting = true
        }
    }
    
    @objc private func userDidInteract() {
        isUserInteracting = true
        lastInteractionTime = Date()
    }
    
    /// Call this from AppDelegate or SceneDelegate when user touches screen
    func recordInteraction() {
        isUserInteracting = true
        lastInteractionTime = Date()
    }
    
    /// Check if user recently interacted
    func hasRecentInteraction() -> Bool {
        guard let lastTime = lastInteractionTime else {
            return false
        }
        return Date().timeIntervalSince(lastTime) < interactionTimeout
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}