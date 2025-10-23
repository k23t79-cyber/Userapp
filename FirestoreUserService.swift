//
//  FirestoreUserService.swift
//  Userapp
//
//  Created by Ri on 10/9/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreUserService {
    static let shared = FirestoreUserService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Step 2: User Data Verification (Matching Android)
    
    /// Check if user exists in Firestore and if security setup is complete
    func getUserDocument(userId: String) async throws -> FirebaseUserDocument {
        print("📊 FIRESTORE: Querying user document for userId: \(userId)")
        
        let docRef = db.collection("users").document(userId)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else {
            print("❌ FIRESTORE: User document not found")
            throw FirestoreError.userNotFound
        }
        
        let data = snapshot.data() ?? [:]
        
        let userDoc = FirebaseUserDocument(
            userId: data["userId"] as? String ?? userId,
            email: data["email"] as? String ?? "",
            securitySetupComplete: data["securitySetupComplete"] as? Bool ?? false,
            primaryDeviceId: data["primaryDeviceId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            securitySetupTimestamp: (data["securitySetupTimestamp"] as? Timestamp)?.dateValue()
        )
        
        print("✅ FIRESTORE: Found user document")
        print("   - Email: \(userDoc.email)")
        print("   - Security setup complete: \(userDoc.securitySetupComplete)")
        print("   - Primary device: \(userDoc.primaryDeviceId ?? "none")")
        
        return userDoc
    }
    
    /// Create a new user document in Firestore
    func createUserDocument(userId: String, email: String, primaryDeviceId: String) async throws {
        print("🔵 FIRESTORE: Creating new user document")
        
        let userData: [String: Any] = [
            "userId": userId,
            "email": email,
            "securitySetupComplete": false,
            "primaryDeviceId": primaryDeviceId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(userData)
        print("✅ FIRESTORE: User document created")
    }
    
    /// Update security setup status
    func updateSecuritySetupComplete(userId: String, completed: Bool) async throws {
        print("🔵 FIRESTORE: Updating securitySetupComplete to \(completed)")
        
        let updateData: [String: Any] = [
            "securitySetupComplete": completed,
            "securitySetupTimestamp": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(updateData, merge: true)
        print("✅ FIRESTORE: Security setup status updated")
    }
    
    /// Update primary device ID
    func updatePrimaryDevice(userId: String, deviceId: String) async throws {
        print("🔵 FIRESTORE: Updating primary device")
        
        let updateData: [String: Any] = [
            "primaryDeviceId": deviceId,
            "primaryDeviceUpdatedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(userId).setData(updateData, merge: true)
        print("✅ FIRESTORE: Primary device updated to \(String(deviceId.prefix(8)))...")
    }
}

enum FirestoreError: Error {
    case userNotFound
    case invalidData
    case updateFailed
    
    var description: String {
        switch self {
        case .userNotFound:
            return "User document not found in Firestore"
        case .invalidData:
            return "Invalid data structure"
        case .updateFailed:
            return "Failed to update Firestore"
        }
    }
}