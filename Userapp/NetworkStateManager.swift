//
//  NetworkStateManager.swift
//  Userapp
//
//  Created by Ri on 9/12/25.
//

import Foundation
import Network
import UIKit

class NetworkStateManager: ObservableObject {
    static let shared = NetworkStateManager()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown
    
    private var wasOffline: Bool = false
    private var connectionChangeHandlers: [(Bool) -> Void] = []
    
    enum ConnectionType {
        case wifi
        case cellular
        case wiredEthernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkChange(path)
            }
        }
        monitor.start(queue: queue)
        print("📡 Started network monitoring")
    }
    
    private func handleNetworkChange(_ path: NWPath) {
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .unknown
        }
        
        print("📡 Network state changed: \(isConnected ? "Connected" : "Offline") (\(connectionType))")
        
        // Handle state transitions
        if !wasConnected && isConnected {
            handleNetworkRecovery()
        } else if wasConnected && !isConnected {
            handleNetworkLoss()
        }
        
        // Notify handlers
        connectionChangeHandlers.forEach { handler in
            handler(isConnected)
        }
    }
    
    // MARK: - Network State Transitions
    
    private func handleNetworkRecovery() {
        print("🟢 Network recovered - triggering offline sync")
        wasOffline = false
        
        // Trigger offline queue processing
        Task {
            await OfflineSyncManager.shared.processOfflineQueue()
        }
        
        // Resume real-time device sync
        NotificationCenter.default.post(
            name: .networkRecovered,
            object: nil
        )
    }
    
    private func handleNetworkLoss() {
        print("🔴 Network lost - entering offline mode")
        wasOffline = true
        
        // Pause real-time sync
        NotificationCenter.default.post(
            name: .networkLost,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func addConnectionChangeHandler(_ handler: @escaping (Bool) -> Void) {
        connectionChangeHandlers.append(handler)
    }
    
    func removeAllHandlers() {
        connectionChangeHandlers.removeAll()
    }
    
    func forceNetworkCheck() {
        // Manually trigger network check
        let path = monitor.currentPath
        handleNetworkChange(path)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let networkRecovered = Notification.Name("NetworkRecovered")
    static let networkLost = Notification.Name("NetworkLost")
}
