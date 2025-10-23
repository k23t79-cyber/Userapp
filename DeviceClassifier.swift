//
//  DeviceClassifier.swift
//  Userapp
//
//  Created by Ri on 10/10/25.
//

import Foundation
import FirebaseFirestore
import UIKit

class DeviceClassifier {
    static let shared = DeviceClassifier()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Main Device Classification Method
    
    /// Check if device is PRIMARY or SECONDARY
    /// If no primary exists, register current device as PRIMARY
    /// - Parameters:
    ///   - userId: The user's unique identifier
    ///   - currentDeviceId: The current device's unique identifier
    /// - Returns: DeviceType (.primary, .secondary, or .unknown)
    func classifyDevice(userId: String, currentDeviceId: String) async -> DeviceType {
        print("🔍 DEVICE CLASSIFIER: Determining device type")
        print("   👤 UserId: \(userId)")
        print("   📱 Current DeviceId: \(String(currentDeviceId.prefix(8)))...")
        
        do {
            // Query device_snapshots collection for this user
            let primaryDoc = try await db.collection("device_snapshots")
                .document(userId)
                .getDocument()
            
            if !primaryDoc.exists {
                // ✅ FIRST TIME LOGIN - No primary device exists
                // Register current device as PRIMARY
                print("✅ No primary device found - registering as PRIMARY")
                try await registerAsPrimaryDevice(userId: userId, deviceId: currentDeviceId)
                return .primary
                
            } else {
                // ✅ RETURNING USER - Primary device exists
                // Compare current device with stored primary device
                let storedPrimaryDeviceId = primaryDoc.data()?["primaryDeviceId"] as? String ?? ""
                
                if storedPrimaryDeviceId == currentDeviceId {
                    // Current device matches primary
                    print("✅ Device matches primary - classified as PRIMARY")
                    return .primary
                } else {
                    // Current device does NOT match primary
                    print("⚠️ Device does NOT match primary - classified as SECONDARY")
                    print("   🔑 Primary Device: \(String(storedPrimaryDeviceId.prefix(8)))...")
                    return .secondary
                }
            }
            
        } catch {
            print("❌ DEVICE CLASSIFIER: Error - \(error)")
            return .unknown
        }
    }
    
    // MARK: - Register as Primary Device
    
    /// Register current device as PRIMARY in Firestore
    /// Creates document in device_snapshots/{userId}
    private func registerAsPrimaryDevice(userId: String, deviceId: String) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let primarySnapshot: [String: Any] = [
            "userId": userId,
            "primaryDeviceId": deviceId,
            "trustScore": NSNull(),
            "syncStatus": "pending",
            "lastUpdated": timestamp,
            "createdAt": timestamp
        ]
        
        try await db.collection("device_snapshots")
            .document(userId)
            .setData(primarySnapshot)
        
        print("✅ Registered as PRIMARY device in Firestore")
        print("   📂 Collection: device_snapshots")
        print("   📄 Document: \(userId)")
        print("   🔑 Primary DeviceId: \(String(deviceId.prefix(8)))...")
    }
    
    // MARK: - Update Primary Device Summary
    
    /// Update PRIMARY device summary with latest trust score
    /// Updates existing document in device_snapshots/{userId}
    func updatePrimaryDeviceSummary(
        userId: String,
        deviceId: String,
        trustScore: Float
    ) async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let updateData: [String: Any] = [
            "trustScore": trustScore,
            "syncStatus": "synced",
            "lastUpdated": timestamp
        ]
        
        try await db.collection("device_snapshots")
            .document(userId)
            .setData(updateData, merge: true)  // Use merge to update only these fields
        
        print("✅ Updated PRIMARY device summary")
        print("   📂 Collection: device_snapshots")
        print("   📄 Document: \(userId)")
        print("   📱 DeviceId: \(String(deviceId.prefix(8)))...")
        print("   📊 Trust Score: \(trustScore)")
    }
}
