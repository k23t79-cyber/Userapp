import Foundation
import RealmSwift
import CoreLocation
import UIKit

class TrustSnapshotManager {
    static let shared = TrustSnapshotManager()
    
    private init() {}
    
    // MARK: - Main Trust Snapshot Creation (Using BOTH Firebase + Supabase)
    
    /// Save comprehensive trust snapshot using Firebase for storage + Supabase for streaming
    func saveTrustSnapshot(for userId: String, email: String) {
        print("💾 Creating comprehensive trust snapshot for userId: \(userId)")
        print("📊 Using FIREBASE for storage + SUPABASE for streaming")
        
        let trustSnapshot = TrustSnapshot()
        trustSnapshot.userId = userId
        trustSnapshot.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Collect all trust signals
        collectSecuritySignals(for: trustSnapshot)
        collectDeviceSignals(for: trustSnapshot)
        collectLocationSignals(for: trustSnapshot)
        collectBehaviorSignals(for: trustSnapshot)
        
        // Calculate trust level based on collected signals
        let trustLevel = calculateTrustLevel(for: trustSnapshot)
        trustSnapshot.trustLevel = trustLevel
        trustSnapshot.score = trustLevel
        trustSnapshot.timestamp = Date()
        
        print("📊 Trust snapshot created with level: \(trustLevel)")
        
        // Step 1: Always save to local Realm first
        saveToRealm(trustSnapshot: trustSnapshot)
        
        // Step 2: Sync to BOTH Firebase (storage) and Supabase (streaming)
        syncToBothFirebaseAndSupabase(trustSnapshot: trustSnapshot, userId: userId, email: email)
    }
    
    func saveTrustSnapshotWithOfflineSupport(for userId: String, email: String) {
        print("💾 Creating comprehensive snapshot with offline support")
        print("📊 UserId: \(userId), Email: \(email)")
        
        let trustSnapshot = TrustSnapshot()
        trustSnapshot.userId = userId
        trustSnapshot.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Collect all trust signals
        collectSecuritySignals(for: trustSnapshot)
        collectDeviceSignals(for: trustSnapshot)
        collectLocationSignals(for: trustSnapshot)
        collectBehaviorSignals(for: trustSnapshot)
        
        // Calculate trust level
        let trustLevel = calculateTrustLevel(for: trustSnapshot)
        trustSnapshot.trustLevel = trustLevel
        trustSnapshot.score = trustLevel
        trustSnapshot.timestamp = Date()
        
        // Step 1: Save to Realm
        saveToRealm(trustSnapshot: trustSnapshot)
        
        // Step 2: Determine priority
        let priority = determinePriority(for: trustSnapshot)
        
        // Step 3: Handle online vs offline
        if NetworkStateManager.shared.isConnected {
            syncOnlineImmediately(trustSnapshot: trustSnapshot, userId: userId, email: email, priority: priority)
        } else {
            queueOfflineSync(trustSnapshot: trustSnapshot, userId: userId, email: email, priority: priority)
        }
    }
    
    // MARK: - Signal Collection Methods (PUBLIC - Exposed for TrustVerifier)
    
    public func collectSecuritySignals(for snapshot: TrustSnapshot) {
        print("   🔒 Collecting security signals...")
        
        snapshot.isJailbroken = DeviceSecurityChecker.isJailbroken()
        snapshot.isVPNEnabled = VPNChecker.shared.isVPNConnected()
        
        print("      Jailbroken: \(snapshot.isJailbroken)")
        print("      VPN: \(snapshot.isVPNEnabled)")
        
        if snapshot.isJailbroken {
            snapshot.addFlag("jailbroken")
        }
        if snapshot.isVPNEnabled {
            snapshot.addFlag("vpn_detected")
        }
    }
    
    public func collectDeviceSignals(for snapshot: TrustSnapshot) {
        print("   📱 Collecting device signals...")
        
        snapshot.uptimeSeconds = Int(ProcessInfo.processInfo.systemUptime)
        snapshot.timezone = TimeZone.current.identifier
        
        print("      Uptime: \(snapshot.uptimeSeconds)s")
        print("      Timezone: \(snapshot.timezone)")
    }
    
    public func collectLocationSignals(for snapshot: TrustSnapshot) {
        print("   📍 Collecting location signals...")
        
        snapshot.location = getCurrentLocation()
        
        print("      Location: \(snapshot.location)")
    }
    
    private func getCurrentLocation() -> String {
        return "0.0,0.0"
    }
    
    public func collectBehaviorSignals(for snapshot: TrustSnapshot) {
        print("   🎭 Collecting behavior signals...")
        
        // ✅ ENHANCED: Collect user interaction
        snapshot.isUserInteracting = UserInteractionMonitor.shared.isUserInteracting
        print("      User Interaction: \(snapshot.isUserInteracting)")
        
        // ✅ NEW: Collect gyroscope motion data
        let motionState = GyroscopeManager.shared.getCurrentMotionState()
        snapshot.motionStateRaw = motionState.rawValue
        
        let metrics = GyroscopeManager.shared.getMotionMetrics()
        snapshot.motionMagnitude = metrics["magnitude"] as? Double ?? 0.0
        
        print("      Motion State: \(motionState.rawValue)")
        print("      Motion Magnitude: \(String(format: "%.3f", snapshot.motionMagnitude)) rad/s")
        
        // ✅ NEW: Run bot detection
        let botReport = BotDetector.shared.detectBot(
            touchInteraction: snapshot.isUserInteracting,
            motionState: motionState,
            motionMagnitude: snapshot.motionMagnitude
        )
        
        print("      🤖 Bot Detection: \(botReport.result.description)")
        
        // Add bot flags if detected
        if botReport.result.isBot {
            snapshot.addFlag("bot_detected")
            print("      ⚠️ BOT FLAG ADDED")
        } else if botReport.result.isSuspicious {
            snapshot.addFlag("suspicious_bot")
            print("      ⚠️ SUSPICIOUS FLAG ADDED")
        }
        
        // Existing risk flags
        if snapshot.isVPNEnabled && snapshot.isJailbroken {
            snapshot.addFlag("high_risk_combination")
        }
        
        if snapshot.uptimeSeconds < 300 {
            snapshot.addFlag("recent_restart")
        }
    }
    
    // MARK: - Trust Level Calculation (PUBLIC - Enhanced with Bot Detection)
    
    public func calculateTrustLevel(for snapshot: TrustSnapshot) -> Int {
        var score = 100
        
        print("   📊 Calculating trust level...")
        
        // Security penalties
        if snapshot.isJailbroken {
            score -= 30
            print("      -30: Jailbroken")
        }
        
        if snapshot.isVPNEnabled {
            score -= 15
            print("      -15: VPN Active")
        }
        
        // ✅ NEW: Bot detection scoring
        let motionState = MotionState(rawValue: snapshot.motionStateRaw) ?? .unknown
        let botReport = BotDetector.shared.detectBot(
            touchInteraction: snapshot.isUserInteracting,
            motionState: motionState,
            motionMagnitude: snapshot.motionMagnitude
        )
        
        // Bot penalties
        switch botReport.result {
        case .bot:
            score -= 40  // Severe penalty for bot
            print("      -40: Bot Detected")
        case .suspicious:
            score -= 20  // Moderate penalty for suspicious
            print("      -20: Suspicious Behavior")
        case .human:
            print("      +0: Human Verified")
        case .unknown:
            score -= 10  // Small penalty for unknown
            print("      -10: Bot Status Unknown")
        }
        
        // Flag penalties
        let flags = snapshot.getFlagsArray()
        
        if flags.contains("high_risk_combination") {
            score -= 20
            print("      -20: High Risk Combination")
        }
        
        if flags.contains("recent_restart") {
            score -= 5
            print("      -5: Recent Restart")
        }
        
        if snapshot.location == "0.0,0.0" {
            score -= 5
            print("      -5: No Location")
        }
        
        let finalScore = max(0, min(100, score))
        print("      ✅ Final Score: \(finalScore)/100")
        
        return finalScore
    }
    
    // MARK: - Priority Determination (Enhanced with Bot Detection)
    
    private func determinePriority(for snapshot: TrustSnapshot) -> String {
        // Critical priority if jailbroken
        if snapshot.isJailbroken {
            return "critical"
        }
        
        // Critical priority if bot detected
        if snapshot.hasFlag("bot_detected") {
            return "critical"
        }
        
        // High priority if trust level very low
        if snapshot.trustLevel < 50 {
            return "high"
        }
        
        // High priority if suspicious bot
        if snapshot.hasFlag("suspicious_bot") {
            return "high"
        }
        
        // High priority if VPN active
        if snapshot.isVPNEnabled {
            return "high"
        }
        
        return "normal"
    }
    
    // MARK: - Dual Sync (Firebase Storage + Supabase Streaming)
    
    private func syncToBothFirebaseAndSupabase(trustSnapshot: TrustSnapshot, userId: String, email: String) {
        print("🔵 Syncing to BOTH Firebase (storage) and Supabase (streaming)")
        
        // ✅ CRITICAL: Extract ALL data BEFORE async Task
        let snapshotId = trustSnapshot.id.stringValue
        let snapshotDict = trustSnapshot.toDictionary()
        let codableData = trustSnapshot.toCodableData()
        let trustLevel = trustSnapshot.trustLevel
        let deviceId = trustSnapshot.deviceId
        
        Task {
            do {
                // 1. Upload encrypted snapshot to Firebase Storage
                try await FirebaseManager.shared.uploadEncryptedSnapshot(
                    userId: userId,
                    snapshotId: snapshotId,
                    codableData: codableData
                )
                print("✅ Encrypted snapshot uploaded to Firebase Storage")
                
                // 2. Add PRIMARY device snapshot to Firebase Firestore
                try await FirebaseManager.shared.addPrimaryDeviceSnapshotHistory(
                    userId: userId,
                    deviceId: deviceId,
                    isPrimary: true,
                    trustScore: Float(trustLevel),
                    snapshotData: snapshotDict
                )
                print("✅ PRIMARY device snapshot stored in Firebase Firestore")
                
                // 3. KEEP Supabase for streaming
                print("📡 Supabase streaming continues in background")
                
            } catch {
                print("❌ Failed to sync to Firebase: \(error)")
            }
        }
    }
    
    private func syncOnlineImmediately(trustSnapshot: TrustSnapshot, userId: String, email: String, priority: String) {
        print("🌐 Immediate dual sync (Firebase + Supabase)")
        
        // ✅ CRITICAL: Extract ALL data from Realm object BEFORE async Task
        let snapshotId = trustSnapshot.id.stringValue
        let snapshotDict = trustSnapshot.toDictionary()
        let codableData = trustSnapshot.toCodableData()
        let trustLevel = trustSnapshot.trustLevel
        let deviceId = trustSnapshot.deviceId
        
        Task {
            do {
                // Upload to Firebase Storage (encrypted)
                try await FirebaseManager.shared.uploadEncryptedSnapshot(
                    userId: userId,
                    snapshotId: snapshotId,
                    codableData: codableData
                )
                
                // Upload to Firebase Firestore (plain)
                try await FirebaseManager.shared.addPrimaryDeviceSnapshotHistory(
                    userId: userId,
                    deviceId: deviceId,
                    isPrimary: true,
                    trustScore: Float(trustLevel),
                    snapshotData: snapshotDict
                )
                
                print("✅ Immediate Firebase sync completed")
                print("📡 Supabase streaming continues in background")
                
            } catch {
                print("❌ Immediate sync failed: \(error)")
                queueOfflineSync(trustSnapshot: trustSnapshot, userId: userId, email: email, priority: priority)
            }
        }
    }
    
    // MARK: - Offline Queue
    
    private func queueOfflineSync(trustSnapshot: TrustSnapshot, userId: String, email: String, priority: String) {
        print("📋 Queuing snapshot for offline sync")
        
        let queuePriority: SyncOperationPriority
        switch priority {
        case "critical":
            queuePriority = .critical
        case "high":
            queuePriority = .high
        default:
            queuePriority = .normal
        }
        
        OfflineSyncManager.shared.queueNewSchemaSnapshotOperation(
            email: email,
            userId: userId,
            trustSnapshot: trustSnapshot,
            operationType: .update,
            priority: queuePriority
        )
        
        print("📋 Snapshot queued for Firebase sync (priority: \(priority))")
    }
    
    // MARK: - Storage Methods (PUBLIC)
    
    public func saveToRealm(trustSnapshot: TrustSnapshot) {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(trustSnapshot, update: .modified)
            }
            print("✅ Trust snapshot saved to Realm")
        } catch {
            print("❌ Failed to save to Realm: \(error)")
        }
    }
    
    // MARK: - Real-time Subscriptions (KEEP USING SUPABASE - NO CHANGES)
    
    func startListeningToDeviceUpdates(userId: String) {
        print("🔔 NOTE: Continue using your existing Supabase subscriptions")
        print("🔔 Firebase is only for storage, not streaming")
        print("🔔 No changes needed to Supabase subscription code")
        
        // Your existing Supabase subscription code continues to work
        // You don't need to call Firebase listeners here
    }
    
    func stopListeningToDeviceUpdates() {
        print("🛑 Stopped listening to device updates")
        // Keep your existing Supabase cleanup code
    }
    
    // MARK: - Helper Methods
    
    func getLatestTrustSnapshot(for userId: String) -> TrustSnapshot? {
        do {
            let realm = try Realm()
            return realm.objects(TrustSnapshot.self)
                .filter("userId == %@", userId)
                .sorted(byKeyPath: "timestamp", ascending: false)
                .first
        } catch {
            print("❌ Error getting latest snapshot: \(error)")
            return nil
        }
    }
    
    func getAllTrustSnapshots(for userId: String) -> [TrustSnapshot] {
        do {
            let realm = try Realm()
            return Array(realm.objects(TrustSnapshot.self)
                .filter("userId == %@", userId)
                .sorted(byKeyPath: "timestamp", ascending: false))
        } catch {
            print("❌ Error getting all snapshots: \(error)")
            return []
        }
    }
    
    private func getUserEmailFromRealm(userId: String) -> String? {
        do {
            let realm = try Realm()
            return realm.objects(UserModel.self)
                .filter("userId == %@", userId)
                .first?.email
        } catch {
            print("❌ Error getting user email: \(error)")
            return nil
        }
    }
}
