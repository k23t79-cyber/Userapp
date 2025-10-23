//
//  TrustVerifier.swift
//  Userapp
//
//  Enhanced with behavior-based decay tracking
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import RealmSwift
import UIKit

class TrustVerifier {
    
    static let shared = TrustVerifier()
    private let db = Firestore.firestore()
    
    private init() {}
    
    // MARK: - Verification Result
    
    enum VerificationResult {
        case trusted(userId: String)
        case requiresSecurityVerification(userId: String, reason: String)
        case blocked(reason: String)
    }
    
    // MARK: - Main Entry Point
    
    func verifyUser(userId: String, email: String, completion: @escaping (VerificationResult) -> Void) {
        print("🔐 TRUST VERIFIER: Starting user verification")
        print("   - UserId: \(userId)")
        print("   - Email: \(email)")
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ TRUST VERIFIER: Error - \(error)")
                completion(.blocked(reason: "Verification failed: \(error.localizedDescription)"))
                return
            }
            
            guard let data = snapshot?.data() else {
                print("⚠️  TRUST VERIFIER: No user document found - NEW USER")
                Task {
                    await self.handleNewUser(userId: userId, email: email, completion: completion)
                }
                return
            }
            
            print("✅ FIRESTORE: Found user document")
            print("   - Email: \(data["email"] ?? "unknown")")
            
            let securityComplete = data["security_setup_complete"] as? Bool ?? false
            print("   - Security setup complete: \(securityComplete)")

            if !securityComplete {
                // NEW USER - Show full setup (multiple questions)
                print("⚠️  TRUST VERIFIER: Security setup incomplete")
                completion(.requiresSecurityVerification(
                    userId: userId,
                    reason: "security_setup"  // ✅ Key for setup flow
                ))
                return
            }

            // ✅ EXISTING USER - Always show verification (1 question)
            print("✅ TRUST VERIFIER: Security setup complete - requiring verification")
            completion(.requiresSecurityVerification(
                userId: userId,
                reason: "security_verification"  // ✅ Key for verification flow
            ))
            // Don't proceed to trust evaluation until security question is answered
        }
    }
    
    // MARK: - Device Classification
    
    func classifyAndVerifyDevice(
        userId: String,
        email: String,
        completion: @escaping (VerificationResult) -> Void
    ) async {
        
        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        print("\n📱 DEVICE CLASSIFICATION")
        print("   Current Device: \(String(currentDeviceId.prefix(8)))...")
        
        let isPrimary = await checkIfPrimaryDevice(userId: userId, deviceId: currentDeviceId)
        
        if isPrimary {
            print("   ✅ Device Type: PRIMARY")
            await handlePrimaryDeviceFlow(
                userId: userId,
                email: email,
                currentDeviceId: currentDeviceId,
                completion: completion
            )
        } else {
            print("   ⚠️  Device Type: SECONDARY")
            await handleSecondaryDeviceFlow(
                userId: userId,
                email: email,
                currentDeviceId: currentDeviceId,
                completion: completion
            )
        }
    }
    
    // MARK: - PRIMARY DEVICE FLOW (BEHAVIOR-BASED)
    
    private func handlePrimaryDeviceFlow(
        userId: String,
        email: String,
        currentDeviceId: String,
        completion: @escaping (VerificationResult) -> Void
    ) async {
        print("\n🔐 PRIMARY DEVICE FLOW: Behavior-based trust verification")
        print("=" + String(repeating: "=", count: 60))
        
        guard let baseline = await Task { @MainActor in
            return fetchBaseline(userId: userId)
        }.value else {
            print("⚠️  No baseline found for PRIMARY device")
            completion(.requiresSecurityVerification(
                userId: userId,
                reason: "No baseline found"
            ))
            return
        }
        
        // Fetch previous trust score
        let previousScore = await Task { @MainActor in
            return baseline.lastTrustScore
        }.value
        
        print("\n📊 STEP 1: Collecting trust signals...")
        
        let baselineCopy = await Task { @MainActor in
            let copy = TrustBaseline()
            copy.userId = baseline.userId
            copy.email = baseline.email
            copy.deviceId = baseline.deviceId
            copy.timezone = baseline.timezone
            copy.systemVersion = baseline.systemVersion
            return copy
        }.value
        
        let trustSignals = await withCheckedContinuation { continuation in
            TrustSignalCollector.shared.collectSignals(
                userId: userId,
                baseline: baselineCopy
            ) { signals in
                continuation.resume(returning: signals)
            }
        }
        
        print(trustSignals.debugDescription())
        
        // Fetch attribute baseline
        let attributeBaseline = await AttributeBaselineManager.shared.fetchBaseline(
            userId: userId,
            deviceId: currentDeviceId
        )
        
        print("\n⚖️  STEP 2: Running behavior-based trust evaluation...")
        let trustReport = await TrustEvaluator.evaluate(
            signals: trustSignals,
            userId: userId,
            attributeBaseline: attributeBaseline
        )
        
        print("\n" + trustReport.summary())
        
        // ═══════════════════════════════════════════
        // STEP 3: TRACK DECAY (Behavior-Based)
        // ═══════════════════════════════════════════
        
        print("\n📉 STEP 3: Tracking behavior-based decay...")
        
        let decaySnapshot = await BehaviorBasedDecayTracker.shared.trackDecay(
            userId: userId,
            deviceId: currentDeviceId,
            previousScore: previousScore,
            currentScore: trustReport.totalScore,
            factors: trustReport.factors
        )
        
        // ═══════════════════════════════════════════
        // STEP 4: CHECK DECAY SEVERITY
        // ═══════════════════════════════════════════
        
        if decaySnapshot.severity == "Critical" {
            print("🚨 CRITICAL DECAY: Possible account takeover")
            
            do {
                try await deleteUser(userId: userId)
                try Auth.auth().signOut()
            } catch {
                print("⚠️  Error: \(error)")
            }
            
            DispatchQueue.main.async {
                completion(.blocked(reason: "Critical behavioral changes detected - possible account takeover"))
            }
            return
        }
        
        if decaySnapshot.severity == "High" {
            print("⚠️  HIGH DECAY: Major behavior change - requiring verification")
            
            DispatchQueue.main.async {
                completion(.requiresSecurityVerification(
                    userId: userId,
                    reason: "Significant behavioral changes detected"
                ))
            }
            return
        }
        
        // ═══════════════════════════════════════════
        // STEP 5: CHECK TRUST SCORE THRESHOLDS
        // ═══════════════════════════════════════════
        
        if trustReport.finalStatus == .blocked || trustReport.isHardBlocked {
            print("\n🚫 PRIMARY DEVICE BLOCKED")
            
            do {
                try await deleteUser(userId: userId)
                try Auth.auth().signOut()
            } catch {
                print("⚠️  Error: \(error)")
            }
            
            DispatchQueue.main.async {
                completion(.blocked(reason: self.formatBlockReason(from: trustReport)))
            }
            return
        }
        
        // ═══════════════════════════════════════════
        // STEP 6: UPDATE BASELINES
        // ═══════════════════════════════════════════
        
        // Save trust snapshot
        TrustSnapshotManager.shared.saveTrustSnapshot(for: userId, email: email)
        
        // Update trust score in baseline
        await updateBaselineAfterTrustEvaluation(
            baseline: baseline,
            trustScore: trustReport.totalScore
        )
        
        // Update attribute baseline with current behavior
        await AttributeBaselineManager.shared.createOrUpdateBaseline(
            userId: userId,
            deviceId: currentDeviceId,
            signals: trustSignals
        )
        
        print("\n✅ PRIMARY DEVICE: Trust verification passed")
        print("   Final Score: \(trustReport.totalScore)/135")
        print("   Decay: \(decaySnapshot.decayAmount) points")
        
        DispatchQueue.main.async {
            if trustReport.finalStatus == .trusted {
                completion(.trusted(userId: userId))
            } else {
                completion(.requiresSecurityVerification(
                    userId: userId,
                    reason: "Trust score: \(trustReport.totalScore)/135"
                ))
            }
        }
    }
    
    // MARK: - SECONDARY DEVICE FLOW (BEHAVIOR-BASED)
    
    private func handleSecondaryDeviceFlow(
        userId: String,
        email: String,
        currentDeviceId: String,
        completion: @escaping (VerificationResult) -> Void
    ) async {
        print("\n💻 SECONDARY DEVICE FLOW")
        print("   📱 DeviceId: \(String(currentDeviceId.prefix(8)))...")
        
        let secondaryBaseline = await fetchSecondaryBaseline(userId: userId, deviceId: currentDeviceId)
        
        if secondaryBaseline == nil {
            print("🆕 SECONDARY: First time on this device")
            await handleFirstTimeSecondaryDevice(
                userId: userId,
                email: email,
                currentDeviceId: currentDeviceId,
                completion: completion
            )
        } else {
            print("🔄 SECONDARY: Returning device")
            await handleReturningSecondaryDevice(
                userId: userId,
                email: email,
                currentDeviceId: currentDeviceId,
                baseline: secondaryBaseline!,
                completion: completion
            )
        }
    }
    
    private func handleFirstTimeSecondaryDevice(
        userId: String,
        email: String,
        currentDeviceId: String,
        completion: @escaping (VerificationResult) -> Void
    ) async {
        print("🆕 SECONDARY (FIRST TIME): Collecting signals and saving baseline")
        
        let trustSignals = await withCheckedContinuation { continuation in
            TrustSignalCollector.shared.collectSignals(
                userId: userId,
                baseline: nil
            ) { signals in
                continuation.resume(returning: signals)
            }
        }
        
        await saveSecondaryBaseline(
            userId: userId,
            deviceId: currentDeviceId,
            email: email,
            signals: trustSignals
        )
        
        // Create attribute baseline for secondary device
        await AttributeBaselineManager.shared.createOrUpdateBaseline(
            userId: userId,
            deviceId: currentDeviceId,
            signals: trustSignals
        )
        
        let snapshot = createSecondarySnapshot(
            userId: userId,
            deviceId: currentDeviceId,
            signals: trustSignals
        )
        
        await saveSecondarySnapshot(snapshot)
        
        print("✅ SECONDARY: Baseline saved")
        
        DispatchQueue.main.async {
            completion(.requiresSecurityVerification(
                userId: userId,
                reason: "New secondary device detected - verification required"
            ))
        }
    }
    
    private func handleReturningSecondaryDevice(
        userId: String,
        email: String,
        currentDeviceId: String,
        baseline: SecondaryDeviceBaseline,
        completion: @escaping (VerificationResult) -> Void
    ) async {
        print("🔄 SECONDARY (RETURNING): Performing behavior-based trust verification")
        
        let previousScore = await Task { @MainActor in
            return baseline.lastTrustScore
        }.value
        
        print("\n📊 STEP 1: Collecting trust signals...")
        
        let baselineCopy = await Task { @MainActor in
            let copy = TrustBaseline()
            copy.userId = baseline.userId
            copy.email = baseline.email
            copy.deviceId = baseline.deviceId
            copy.timezone = baseline.timezone
            copy.systemVersion = baseline.systemVersion
            return copy
        }.value
        
        let trustSignals = await withCheckedContinuation { continuation in
            TrustSignalCollector.shared.collectSignals(
                userId: userId,
                baseline: baselineCopy
            ) { signals in
                continuation.resume(returning: signals)
            }
        }
        
        print(trustSignals.debugDescription())
        
        // Fetch attribute baseline
        let attributeBaseline = await AttributeBaselineManager.shared.fetchBaseline(
            userId: userId,
            deviceId: currentDeviceId
        )
        
        print("\n⚖️  STEP 2: Running behavior-based trust evaluation...")
        let trustReport = await TrustEvaluator.evaluate(
            signals: trustSignals,
            userId: userId,
            attributeBaseline: attributeBaseline
        )
        
        print("\n" + trustReport.summary())
        
        // ═══════════════════════════════════════════
        // STEP 3: TRACK DECAY (Behavior-Based)
        // ═══════════════════════════════════════════
        
        print("\n📉 STEP 3: Tracking behavior-based decay...")
        
        let decaySnapshot = await BehaviorBasedDecayTracker.shared.trackDecay(
            userId: userId,
            deviceId: currentDeviceId,
            previousScore: previousScore,
            currentScore: trustReport.totalScore,
            factors: trustReport.factors
        )
        
        // ═══════════════════════════════════════════
        // STEP 4: CHECK DECAY SEVERITY
        // ═══════════════════════════════════════════
        
        if decaySnapshot.severity == "Critical" || decaySnapshot.severity == "High" {
            print("⚠️  \(decaySnapshot.severity.uppercased()) DECAY: Removing secondary device")
            
            await deleteSecondaryDevice(userId: userId, deviceId: currentDeviceId)
            
            DispatchQueue.main.async {
                completion(.blocked(reason: "Device removed due to suspicious behavioral changes"))
            }
            return
        }
        
        // ═══════════════════════════════════════════
        // STEP 5: CHECK TRUST SCORE
        // ═══════════════════════════════════════════
        
        if trustReport.finalStatus == .blocked || trustReport.isHardBlocked {
            print("\n🚫 SECONDARY DEVICE BLOCKED")
            
            await deleteSecondaryDevice(userId: userId, deviceId: currentDeviceId)
            
            DispatchQueue.main.async {
                completion(.blocked(reason: self.formatBlockReason(from: trustReport)))
            }
            return
        }
        
        // ═══════════════════════════════════════════
        // STEP 6: UPDATE BASELINES AND SNAPSHOTS
        // ═══════════════════════════════════════════
        
        let snapshot = createSecondarySnapshot(
            userId: userId,
            deviceId: currentDeviceId,
            signals: trustSignals
        )
        snapshot.trustLevel = trustReport.totalScore
        snapshot.score = trustReport.totalScore
        
        if let botReport = trustReport.botDetectionReport {
            if botReport.result.isBot {
                snapshot.addFlag("bot_detected")
            }
        }
        
        await saveSecondarySnapshot(snapshot)
        
        // Update trust score
        await Task { @MainActor in
            do {
                let realm = try Realm()
                try realm.write {
                    baseline.lastTrustScore = trustReport.totalScore
                    baseline.lastLoginDate = Date()
                }
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
        
        // Update attribute baseline
        await AttributeBaselineManager.shared.createOrUpdateBaseline(
            userId: userId,
            deviceId: currentDeviceId,
            signals: trustSignals
        )
        
        print("\n✅ SECONDARY DEVICE: Trust verification complete")
        print("   Final Score: \(trustReport.totalScore)/135")
        print("   Decay: \(decaySnapshot.decayAmount) points")
        
        DispatchQueue.main.async {
            if trustReport.totalScore >= 70 {
                completion(.trusted(userId: userId))
            } else if trustReport.totalScore >= 45 {
                completion(.requiresSecurityVerification(
                    userId: userId,
                    reason: "Trust score: \(trustReport.totalScore)/135 - verification required"
                ))
            } else {
                completion(.blocked(reason: "Trust score too low: \(trustReport.totalScore)/135"))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchSecondaryBaseline(userId: String, deviceId: String) async -> SecondaryDeviceBaseline? {
        return await Task { @MainActor in
            do {
                let realm = try Realm()
                return realm.objects(SecondaryDeviceBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first
            } catch {
                return nil
            }
        }.value
    }
    
    private func saveSecondaryBaseline(userId: String, deviceId: String, email: String, signals: TrustSignals) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                let baseline = SecondaryDeviceBaseline()
                baseline.userId = userId
                baseline.deviceId = deviceId
                baseline.email = email
                baseline.timezone = signals.timezone
                baseline.systemVersion = signals.systemVersion
                baseline.createdAt = Date()
                baseline.lastTrustScore = 100
                baseline.lastLoginDate = Date()
                
                try realm.write { realm.add(baseline) }
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
    }
    
    private func createSecondarySnapshot(userId: String, deviceId: String, signals: TrustSignals) -> SecondaryDeviceSnapshot {
        let snapshot = SecondaryDeviceSnapshot()
        snapshot.userId = userId
        snapshot.deviceId = deviceId
        snapshot.timestamp = Date()
        snapshot.isJailbroken = signals.isJailbroken
        snapshot.isVPNEnabled = signals.isVPNEnabled
        snapshot.isUserInteracting = signals.isUserInteracting
        snapshot.motionStateRaw = signals.motionState
        snapshot.motionMagnitude = signals.motionMagnitude
        snapshot.appAttestVerified = signals.appAttestVerified
        snapshot.appAttestScore = signals.appAttestScore
        snapshot.appAttestRiskLevel = signals.appAttestRiskLevel
        snapshot.appAttestKeyId = signals.appAttestKeyId
        snapshot.timezone = signals.timezone
        snapshot.location = signals.location ?? "0.0,0.0"
        snapshot.uptimeSeconds = signals.uptimeSeconds
        snapshot.systemVersion = signals.systemVersion
        snapshot.networkType = signals.networkType
        snapshot.syncStatusRaw = "pending"
        return snapshot
    }
    
    private func saveSecondarySnapshot(_ snapshot: SecondaryDeviceSnapshot) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                try realm.write { realm.add(snapshot) }
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
    }
    
    private func deleteSecondaryDevice(userId: String, deviceId: String) async {
        await Task { @MainActor in
            do {
                let realm = try await Realm()
                
                if let baseline = realm.objects(SecondaryDeviceBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first {
                    try realm.write { realm.delete(baseline) }
                }
                
                let snapshots = realm.objects(SecondaryDeviceSnapshot.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                
                try realm.write { realm.delete(snapshots) }
                
                // Delete attribute baseline
                if let attributeBaseline = realm.objects(AttributeBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first {
                    try realm.write { realm.delete(attributeBaseline) }
                }
                
                await deleteFirestoreDeviceSnapshots(userId: userId, deviceId: deviceId)
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
    }
    
    private func fetchBaseline(userId: String) -> TrustBaseline? {
        do {
            let realm = try Realm()
            return realm.objects(TrustBaseline.self).filter("userId == %@", userId).first
        } catch {
            return nil
        }
    }
    
    private func checkIfPrimaryDevice(userId: String, deviceId: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("trust_snapshots")
                .whereField("device_id", isEqualTo: deviceId)
                .whereField("device_type", isEqualTo: "PRIMARY")
                .limit(to: 1)
                .getDocuments()
            
            return !snapshot.documents.isEmpty
        } catch {
            return false
        }
    }
    
    private func handleNewUser(userId: String, email: String, completion: @escaping (VerificationResult) -> Void) async {
        DispatchQueue.main.async {
            completion(.requiresSecurityVerification(userId: userId, reason: "security_setup"))
        }
    }
    
    private func deleteUser(userId: String) async throws {
        try await Task { @MainActor in
            let realm = try Realm()
            
            if let user = realm.objects(UserModel.self).filter("userId == %@", userId).first {
                try realm.write { realm.delete(user) }
            }
            
            let baselines = realm.objects(TrustBaseline.self).filter("userId == %@", userId)
            let secondaryBaselines = realm.objects(SecondaryDeviceBaseline.self).filter("userId == %@", userId)
            let attributeBaselines = realm.objects(AttributeBaseline.self).filter("userId == %@", userId)
            let decaySnapshots = realm.objects(DecaySnapshot.self).filter("userId == %@", userId)
            
            try realm.write {
                realm.delete(baselines)
                realm.delete(secondaryBaselines)
                realm.delete(attributeBaselines)
                realm.delete(decaySnapshots)
            }
        }.value
    }
    
    private func formatBlockReason(from report: TrustEvaluationReport) -> String {
        if let factor = report.factors.first {
            return factor.description()
        }
        return "Trust verification failed"
    }
    
    private func updateBaselineAfterTrustEvaluation(baseline: TrustBaseline, trustScore: Int) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                try realm.write {
                    baseline.lastTrustScore = trustScore
                    baseline.lastLoginDate = Date()
                    baseline.updatedAt = Date()
                }
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
    }
    
    private func deleteFirestoreDeviceSnapshots(userId: String, deviceId: String) async {
        do {
            let snapshots = try await db.collection("users")
                .document(userId)
                .collection("trust_snapshots")
                .whereField("device_id", isEqualTo: deviceId)
                .getDocuments()
            
            for doc in snapshots.documents {
                try await doc.reference.delete()
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
