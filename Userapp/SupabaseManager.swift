import Foundation
import Supabase
import UIKit
import RealmSwift

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let client: SupabaseClient
    
    private init() {
        let supabaseUrl = URL(string: "https://ojhodugbjutzpaguubfh.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qaG9kdWdianV0enBhZ3V1YmZoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIwNDI1NzgsImV4cCI6MjA2NzYxODU3OH0.SkkfDHdl4oa6sv9Od9-W-3iJaFggX1HZ1Ztey7v4nUo"
        client = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey)
    }
    
    // MARK: - OTP Methods
    func sendOTP(to email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await client.auth.signInWithOTP(email: email)
                print("✅ OTP sent to \(email)")
                completion(.success(()))
            } catch {
                print("❌ Failed to send OTP: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func verifyOTP(email: String, token: String, type: EmailOTPType, completion: @escaping (Result<Session, Error>) -> Void) {
        Task {
            do {
                let authResponse = try await client.auth.verifyOTP(email: email, token: token, type: type)
                if let session = authResponse.session {
                    print("✅ OTP verification succeeded")
                    completion(.success(session))
                } else {
                    print("❌ No session found after verification")
                    completion(.failure(NSError(domain: "Supabase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session not found in auth response."])))
                }
            } catch {
                print("❌ OTP verification failed: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    //    // MARK: - Thread-Safe Method with UserId as Primary Key
    //
    //    func upsertUserSnapshotWithData(
    //        email: String,
    //        userId: String,
    //        updatingDeviceId: String,
    //        trustScore: Double,
    //        snapshotData: [String: Any]
    //    ) async throws {
    //
    //        print("📤 SUPABASE: Upserting user snapshot for userId: \(userId)")
    //        print("📤 Email: \(email)")
    //        print("📤 Device: \(String(updatingDeviceId.prefix(8)))...")
    //        print("📤 Trust Score: \(trustScore)")
    //        print("📤 Snapshot data keys: \(snapshotData.keys.joined(separator: ", "))")
    //
    //        let isPrimaryDevice = try await shouldBeUserPrimaryDevice(userId: userId, deviceId: updatingDeviceId)
    //        let primaryDeviceId = isPrimaryDevice ? updatingDeviceId : await getCurrentUserPrimaryDevice(userId: userId)
    //
    //        print("📤 Device role: \(isPrimaryDevice ? "PRIMARY" : "SECONDARY")")
    //        print("📤 Primary device ID: \(String(primaryDeviceId.prefix(8)))...")
    //
    //        try await updateSummaryTable(
    //            userId: userId,
    //            primaryDeviceId: primaryDeviceId,
    //            trustScore: trustScore,
    //            isPrimary: isPrimaryDevice
    //        )
    //
    //        try await addHistoryEntry(
    //            userId: userId,
    //            deviceId: updatingDeviceId,
    //            isPrimary: isPrimaryDevice,
    //            trustScore: trustScore,
    //            snapshotData: snapshotData
    //        )
    //
    //        print("✅ SUPABASE: User snapshot synced successfully")
    //        print("✅ Device role: \(isPrimaryDevice ? "PRIMARY" : "SECONDARY")")
    //    }
    //
    //    // MARK: - Main Upsert Method
    //
    //    func upsertUserSnapshot(
    //        email: String,
    //        userId: String,
    //        updatingDeviceId: String,
    //        trustScore: Double,
    //        trustSnapshot: TrustSnapshot? = nil
    //    ) async throws {
    //
    //        print("📤 SUPABASE: Upserting user snapshot for userId: \(userId)")
    //        print("📤 Email: \(email)")
    //        print("📤 Device: \(String(updatingDeviceId.prefix(8)))...")
    //        print("📤 Trust Score: \(trustScore)")
    //
    //        let snapshotData: [String: Any]
    //        if let snapshot = trustSnapshot {
    //            snapshotData = await MainActor.run {
    //                return snapshot.toDictionary()
    //            }
    //        } else {
    //            snapshotData = getLatestTrustSignalsFromRealm(userId: userId, deviceId: updatingDeviceId)
    //        }
    //
    //        print("📤 Snapshot data keys: \(snapshotData.keys.joined(separator: ", "))")
    //
    //        let isPrimaryDevice = try await shouldBeUserPrimaryDevice(userId: userId, deviceId: updatingDeviceId)
    //        let primaryDeviceId = isPrimaryDevice ? updatingDeviceId : await getCurrentUserPrimaryDevice(userId: userId)
    //
    //        print("📤 Device role: \(isPrimaryDevice ? "PRIMARY" : "SECONDARY")")
    //        print("📤 Primary device ID: \(String(primaryDeviceId.prefix(8)))...")
    //
    //        try await updateSummaryTable(
    //            userId: userId,
    //            primaryDeviceId: primaryDeviceId,
    //            trustScore: trustScore,
    //            isPrimary: isPrimaryDevice
    //        )
    //
    //        try await addHistoryEntry(
    //            userId: userId,
    //            deviceId: updatingDeviceId,
    //            isPrimary: isPrimaryDevice,
    //            trustScore: trustScore,
    //            snapshotData: snapshotData
    //        )
    //
    //        print("✅ SUPABASE: User snapshot updated successfully")
    //    }
    //
    //    // MARK: - Summary Table Operations
    //
    //    private func updateSummaryTable(
    //        userId: String,
    //        primaryDeviceId: String,
    //        trustScore: Double,
    //        isPrimary: Bool
    //    ) async throws {
    //
    //        struct DeviceSnapshotUpsert: Encodable {
    //            let user_id: String
    //            let device_id: String
    //            let is_primary: Bool
    //            let trust_score: Float
    //            let sync_status: String
    //        }
    //
    //        let summary = DeviceSnapshotUpsert(
    //            user_id: userId,
    //            device_id: primaryDeviceId,
    //            is_primary: isPrimary,
    //            trust_score: Float(trustScore),
    //            sync_status: "synced"
    //        )
    //
    //        print("📊 SUPABASE: Upserting to device_snapshots table")
    //        print("📊 user_id: \(userId)")
    //        print("📊 device_id: \(String(primaryDeviceId.prefix(8)))...")
    //        print("📊 is_primary: \(isPrimary)")
    //        print("📊 trust_score: \(Float(trustScore))")
    //
    //        do {
    //            try await client.database
    //                .from("device_snapshots")
    //                .upsert(summary, onConflict: "user_id")
    //                .execute()
    //
    //            print("✅ SUPABASE: Summary table upserted successfully")
    //
    //        } catch {
    //            print("❌ SUPABASE: Failed to upsert summary table")
    //            print("❌ Error: \(error)")
    //            if let supabaseError = error as? PostgrestError {
    //                print("❌ Postgrest Error: \(supabaseError)")
    //            }
    //            throw error
    //        }
    //    }
    //
    //    // MARK: - History Table Operations
    //
    //    private func addHistoryEntry(
    //        userId: String,
    //        deviceId: String,
    //        isPrimary: Bool,
    //        trustScore: Double,
    //        snapshotData: [String: Any]
    //    ) async throws {
    //
    //        struct DeviceSnapshotHistoryInsert: Encodable {
    //            let user_id: String
    //            let device_id: String
    //            let is_primary: Bool
    //            let trust_score: Float?
    //            let sync_status: String
    //            let snapshot_data: String
    //        }
    //
    //        let jsonData = try JSONSerialization.data(withJSONObject: snapshotData)
    //        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
    //
    //        let historyEntry = DeviceSnapshotHistoryInsert(
    //            user_id: userId,
    //            device_id: deviceId,
    //            is_primary: isPrimary,
    //            trust_score: Float(trustScore),
    //            sync_status: "pending",
    //            snapshot_data: jsonString
    //        )
    //
    //        print("📊 SUPABASE: Inserting to device_snapshots_history table")
    //        print("📊 user_id: \(userId)")
    //        print("📊 device_id: \(String(deviceId.prefix(8)))...")
    //        print("📊 snapshot_data length: \(jsonString.count) characters")
    //
    //        do {
    //            try await client.database
    //                .from("device_snapshots_history")
    //                .insert(historyEntry)
    //                .execute()
    //
    //            print("✅ SUPABASE: History entry added successfully")
    //
    //        } catch {
    //            print("❌ SUPABASE: Failed to add history entry")
    //            print("❌ Error: \(error)")
    //            throw error
    //        }
    //    }
    //
    //    // MARK: - User Actions Streaming (FIXED: matches Android schema)
    //
    //    func pushActionToSupabase(
    //        userId: String,
    //        deviceId: String,
    //        actionType: String,
    //        payloadJSON: String
    //    ) async throws -> String {
    //
    //        struct UserActionInsert: Encodable {
    //            let user_id: String
    //            let device_id: String
    //            let type: String        // CHANGED: matches Android "type" field
    //            let payload: String
    //        }
    //
    //        let action = UserActionInsert(
    //            user_id: userId,
    //            device_id: deviceId,
    //            type: actionType,       // CHANGED: maps to "type" column
    //            payload: payloadJSON
    //        )
    //
    //        print("📤 SUPABASE ACTION: Pushing \(actionType)")
    //        print("📤 User: \(userId)")
    //        print("📤 Device: \(String(deviceId.prefix(8)))...")
    //        struct ActionResponse: Decodable {
    //            let id: String
    //        }
    //
    //        do {
    //            let response: [ActionResponse] = try await client.database
    //                .from("user_actions")
    //                .insert(action)
    //                .select()
    //                .execute()
    //                .value
    //
    //            guard let actionId = response.first?.id else {
    //                throw NSError(domain: "SupabaseManager", code: -1,
    //                            userInfo: [NSLocalizedDescriptionKey: "No action ID returned"])
    //            }
    //
    //            print("✅ SUPABASE ACTION: Pushed successfully - ID: \(actionId)")
    //            return actionId
    //
    //        } catch {
    //            print("❌ SUPABASE ACTION: Failed to push")
    //            print("❌ Error: \(error)")
    //            throw error
    //        }
    //    }
    //
    //    func getRecentActions(userId: String, limit: Int = 50) async throws -> [SupabaseUserAction] {
    //        print("📊 SUPABASE ACTION: Fetching recent actions for user: \(userId)")
    //
    //        do {
    //            let response: [SupabaseUserAction] = try await client.database
    //                .from("user_actions")
    //                .select()
    //                .eq("user_id", value: userId)
    //                .order("created_at", ascending: false)
    //                .limit(limit)
    //                .execute()
    //                .value
    //
    //            print("✅ SUPABASE ACTION: Found \(response.count) actions")
    //            return response
    //
    //        } catch {
    //            print("❌ SUPABASE ACTION: Failed to fetch actions")
    //            print("❌ Error: \(error)")
    //            throw error
    //        }
    //    }
    //
    //    func startActionPolling(
    //        userId: String,
    //        interval: TimeInterval = 3.0,
    //        onNewAction: @escaping (SupabaseUserAction) -> Void
    //    ) -> Timer {
    //        print("📡 SUPABASE ACTION: Starting polling for user: \(userId)")
    //
    //        var lastActionId: String?
    //
    //        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    //            Task {
    //                do {
    //                    let actions = try await self.getRecentActions(userId: userId, limit: 5)
    //
    //                    if let latestAction = actions.first {
    //                        if lastActionId == nil {
    //                            lastActionId = latestAction.id
    //                        } else if latestAction.id != lastActionId {
    //                            print("📨 SUPABASE ACTION: New action detected - \(latestAction.type)")
    //                            lastActionId = latestAction.id
    //
    //                            let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
    //                            if latestAction.device_id != currentDeviceId {
    //                                DispatchQueue.main.async {
    //                                    onNewAction(latestAction)
    //                                }
    //                            }
    //                        }
    //                    }
    //
    //                } catch {
    //                    print("❌ SUPABASE ACTION: Polling error - \(error)")
    //                }
    //            }
    //        }
    //
    //        timer.fire()
    //        return timer
    //    }
    //
    //    func getActionStats(userId: String) async throws -> ActionQueueStats {
    //        print("📊 SUPABASE ACTION: Getting stats for user: \(userId)")
    //
    //        do {
    //            let allActions = try await getRecentActions(userId: userId, limit: 1000)
    //
    //            let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
    //            let deviceActions = allActions.filter { $0.device_id == currentDeviceId }
    //            let otherDeviceActions = allActions.filter { $0.device_id != currentDeviceId }
    //
    //            let stats = ActionQueueStats(
    //                totalActions: allActions.count,
    //                deviceActions: deviceActions.count,
    //                otherDeviceActions: otherDeviceActions.count,
    //                lastActionTime: allActions.first?.created_at
    //            )
    //
    //            print("✅ SUPABASE ACTION: Stats - Total: \(stats.totalActions), This device: \(stats.deviceActions), Others: \(stats.otherDeviceActions)")
    //
    //            return stats
    //
    //        } catch {
    //            print("❌ SUPABASE ACTION: Failed to get stats")
    //            throw error
    //        }
    //    }
    //
    //    // MARK: - Query Methods
    //
    //    func getUserSummary(for userId: String) async throws -> DeviceSnapshotSummary? {
    //        print("📊 SUPABASE: Querying user summary for userId: \(userId)")
    //
    //        do {
    //            let response: [DeviceSnapshotSummary] = try await client.database
    //                .from("device_snapshots")
    //                .select()
    //                .eq("user_id", value: userId)
    //                .limit(1)
    //                .execute()
    //                .value
    //
    //            if let summary = response.first {
    //                print("✅ SUPABASE: Found user summary")
    //                print("✅ Device: \(String(summary.device_id.prefix(8)))...")
    //                print("✅ Trust score: \(summary.trust_score ?? 0)")
    //                return summary
    //            } else {
    //                print("📊 SUPABASE: No summary found for userId: \(userId)")
    //                return nil
    //            }
    //
    //        } catch {
    //            print("❌ SUPABASE: Failed to get user summary: \(error)")
    //            throw error
    //        }
    //    }
    //
    //    func getUserHistory(for userId: String, limit: Int = 20) async throws -> [DeviceSnapshotHistory] {
    //        print("📊 SUPABASE: Querying user history for userId: \(userId), limit: \(limit)")
    //
    //        do {
    //            let response: [DeviceSnapshotHistory] = try await client.database
    //                .from("device_snapshots_history")
    //                .select()
    //                .eq("user_id", value: userId)
    //                .order("created_at", ascending: false)
    //                .limit(limit)
    //                .execute()
    //                .value
    //
    //            print("✅ SUPABASE: Found \(response.count) history entries")
    //            return response
    //
    //        } catch {
    //            print("❌ SUPABASE: Failed to get user history: \(error)")
    //            throw error
    //        }
    //    }
    //
    //    // MARK: - Device Management
    //
    //    private func shouldBeUserPrimaryDevice(userId: String, deviceId: String) async throws -> Bool {
    //        if let existingSummary = try await getUserSummary(for: userId) {
    //            let isPrimary = existingSummary.device_id == deviceId
    //            print("📊 Device \(String(deviceId.prefix(8)))... is \(isPrimary ? "PRIMARY" : "SECONDARY")")
    //            return isPrimary
    //        }
    //
    //        print("📊 Device \(String(deviceId.prefix(8)))... becomes PRIMARY (new user)")
    //        return true
    //    }
    //
    //    private func getCurrentUserPrimaryDevice(userId: String) async -> String {
    //        do {
    //            if let summary = try await getUserSummary(for: userId) {
    //                print("📊 Current primary device: \(String(summary.device_id.prefix(8)))...")
    //                return summary.device_id
    //            }
    //        } catch {
    //            print("❌ Error getting primary device: \(error)")
    //        }
    //
    //        let fallback = UIDevice.current.deviceIdentifier
    //        print("📊 Using fallback device: \(String(fallback.prefix(8)))...")
    //        return fallback
    //    }
    //
    //    // MARK: - Subscriptions
    //
    //    func subscribeToUserSummary(userId: String, onUpdate: @escaping (DeviceSnapshotSummary) -> Void) {
    //        print("📡 SUPABASE: Starting summary subscription for userId: \(userId)")
    //
    //        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
    //            Task {
    //                do {
    //                    if let summary = try await self.getUserSummary(for: userId) {
    //                        let currentDeviceId = UIDevice.current.deviceIdentifier
    //
    //                        if summary.device_id != currentDeviceId {
    //                            print("📡 SUPABASE: Summary updated by device: \(String(summary.device_id.prefix(8)))...")
    //                            DispatchQueue.main.async {
    //                                onUpdate(summary)
    //                            }
    //                        }
    //                    }
    //                } catch {
    //                    print("❌ SUPABASE: Failed to poll summary: \(error)")
    //                }
    //            }
    //        }
    //    }
    //
    //    func subscribeToUserHistory(userId: String, onNewEntry: @escaping (DeviceSnapshotHistory) -> Void) {
    //        print("📡 SUPABASE: Starting history subscription for userId: \(userId)")
    //
    //        var lastHistoryCount = 0
    //
    //        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
    //            Task {
    //                do {
    //                    let historyEntries = try await self.getUserHistory(for: userId, limit: 5)
    //
    //                    if historyEntries.count > lastHistoryCount {
    //                        lastHistoryCount = historyEntries.count
    //
    //                        if let latestEntry = historyEntries.first {
    //                            let currentDeviceId = UIDevice.current.deviceIdentifier
    //
    //                            if latestEntry.device_id != currentDeviceId {
    //                                print("📡 SUPABASE: New history entry from device: \(String(latestEntry.device_id.prefix(8)))...")
    //                                DispatchQueue.main.async {
    //                                    onNewEntry(latestEntry)
    //                                }
    //                            }
    //                        }
    //                    }
    //                } catch {
    //                    print("❌ SUPABASE: Failed to poll history: \(error)")
    //                }
    //            }
    //        }
    //    }
    //
    //    func unsubscribeFromUser() {
    //        print("🛑 SUPABASE: Stopped polling")
    //    }
    //
    //    // MARK: - Helper Methods
    //
    //    private func getLatestTrustSignalsFromRealm(userId: String, deviceId: String) -> [String: Any] {
    //        print("📊 Getting trust signals from Realm for userId: \(userId)")
    //
    //        let snapshotData = MainActor.assumeIsolated {
    //            do {
    //                let realm = try Realm()
    //
    //                if let latestSnapshot = realm.objects(TrustSnapshot.self)
    //                    .filter("userId == %@", userId)
    //                    .sorted(byKeyPath: "timestamp", ascending: false)
    //                    .first {
    //
    //                    print("📊 Found trust snapshot in Realm")
    //                    return latestSnapshot.toDictionary()
    //                }
    //            } catch {
    //                print("❌ Error accessing Realm: \(error)")
    //            }
    //
    //            return [String: Any]()
    //        }
    //
    //        if snapshotData.isEmpty {
    //            print("⚠️ No Realm data - using fallback")
    //            return createFallbackTrustSignals(userId: userId, deviceId: deviceId)
    //        }
    //
    //        return snapshotData
    //    }
    //
    //    private func createFallbackTrustSignals(userId: String, deviceId: String) -> [String: Any] {
    //        return [
    //            "id": UUID().uuidString,
    //            "userId": userId,
    //            "deviceId": deviceId,
    //            "isJailbroken": DeviceSecurityChecker.isJailbroken(),
    //            "isVPNEnabled": VPNChecker.shared.isVPNConnected(),
    //            "isUserInteracting": true,
    //            "uptimeSeconds": ProcessInfo.processInfo.systemUptime,
    //            "timezone": TimeZone.current.identifier,
    //            "timestamp": Date().timeIntervalSince1970,
    //            "location": "0.0,0.0",
    //            "trustLevel": 50,
    //            "score": 50,
    //            "syncStatus": "pending"
    //        ]
    //    }
    //}
    //
    //// MARK: - Data Models
    //
    //struct DeviceSnapshotSummary: Codable {
    //    let id: String?
    //    let user_id: String
    //    let device_id: String
    //    let is_primary: Bool
    //    let last_updated: String?
    //    let trust_score: Float?
    //    let sync_status: String?
    //    let created_at: String?
    //}
    //
    //
    //// MARK: - User Actions Data Models (FIXED: matches Android schema)
    //
    //struct SupabaseUserAction: Codable {
    //    let id: String
    //    let user_id: String
    //    let device_id: String
    //    let type: String            // CHANGED: matches Android "type" field
    //    let payload: String
    //    let created_at: String
    //
    //    func getPayloadDict() -> [String: Any]? {
    //        guard let jsonData = payload.data(using: .utf8) else { return nil }
    //        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    //    }
    //}
    //
    //struct ActionQueueStats {
    //    let totalActions: Int
    //    let deviceActions: Int
    //    let otherDeviceActions: Int
    //    let lastActionTime: String?
    //}
}
