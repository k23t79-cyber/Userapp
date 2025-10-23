//
//  RealmManager.swift
//  Userapp
//
import Foundation
import RealmSwift

class RealmManager {
    static let shared = RealmManager()
    private var realm: Realm?
    
    private init() {
        configureRealm()
    }
    
    private func configureRealm() {
        print("⚙️ configureRealm() called")
        
        let config = Realm.Configuration(
            schemaVersion: 54,  // ✅ INCREMENT from 53 to 54
            migrationBlock: { migration, oldSchemaVersion in
                print("Running migration from schema v\(oldSchemaVersion) → v54")
                
                if oldSchemaVersion < 47 {
                    print("Added UserActionQueue model")
                }
                if oldSchemaVersion < 47 {
                    print("Added UserProfile model")
                }
                if oldSchemaVersion < 49 {
                    print("Added TrustBaseline model")
                }
                if oldSchemaVersion < 50 {
                    print("Added updatedAt to TrustBaseline")
                }
                if oldSchemaVersion < 51 {
                    print("Added SecondaryDeviceBaseline model")
                }
                if oldSchemaVersion < 52 {
                    print("Added SecondaryDeviceSnapshot model")
                }
                if oldSchemaVersion < 53 {
                    print("✅ Added decay tracking fields (lastLoginDate, lastTrustScore, consecutiveActiveDays, inactiveDayCounter)")
                }
                if oldSchemaVersion < 54 {
                    print("✅ Added AttributeBaseline and DecaySnapshot for behavior-based decay tracking")
                    print("✅ Removed consecutiveActiveDays and inactiveDayCounter from TrustBaseline (no longer needed)")
                }
            },
            objectTypes: [
                UserModel.self,
                TrustSnapshot.self,
                LocationClusterObject.self,
                EmbeddedLocation.self,
                QueuedSyncOperation.self,
                QueuedNewSchemaOperation.self,
                QueuedUserSnapshotOperation.self,
                LocationVisit.self,
                UserActionQueue.self,
                UserProfile.self,
                TrustBaseline.self,
                SecondaryDeviceBaseline.self,
                SecondaryDeviceSnapshot.self,
                TrustSignalEvent.self,
                AttributeBaseline.self,           // ✅ NEW: Behavior baseline tracking
                DecaySnapshot.self                // ✅ NEW: Decay history tracking
            ]
        )
        
        Realm.Configuration.defaultConfiguration = config
        
        do {
            realm = try Realm()
            if let fileURL = realm?.configuration.fileURL {
                print("Realm initialized at: \(fileURL)")
            }
            print("SUCCESS: Realm initialized at: \(realm?.configuration.fileURL)")
        } catch {
            print("Failed to initialize Realm: \(error.localizedDescription)")
            if let fileURL = Realm.Configuration.defaultConfiguration.fileURL {
                let folderPath = fileURL.deletingLastPathComponent()
                do {
                    try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true)
                    let paths = [
                        fileURL,
                        folderPath.appendingPathComponent("default.realm.lock"),
                        folderPath.appendingPathComponent("default.realm.management")
                    ]
                    for path in paths {
                        if FileManager.default.fileExists(atPath: path.path) {
                            try FileManager.default.removeItem(at: path)
                            print("Deleted: \(path.lastPathComponent)")
                        }
                    }
                    print("Old Realm cleaned up. Retrying initialization...")
                    realm = try Realm()
                    if let fileURL = realm?.configuration.fileURL {
                        print("Realm re-initialized successfully after reset at: \(fileURL)")
                    }
                } catch {
                    fatalError("Still failed to initialize Realm after reset: \(error)")
                }
            }
        }
    }
    
    // MARK: - Get Realm Instance
    func getRealmInstance() -> Realm? {
        return realm
    }
    
    // MARK: - Save User
    func saveUser(userId: String, email: String, name: String, method: String) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        let user = UserModel()
        user.userId = userId
        user.email = email
        user.name = name
        user.method = method
        user.signedInAt = Date()
        do {
            try realm.write {
                realm.add(user, update: .modified)
            }
            print("Saved user: \(user.name) (\(user.email)) via \(user.method)")
        } catch {
            print("Error saving user: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch All Users
    func fetchAllUsers() -> [UserModel] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(UserModel.self))
    }
    
    // MARK: - Fetch Latest User
    func fetchLatestUser() -> UserModel? {
        guard let realm = realm else { return nil }
        return realm.objects(UserModel.self).sorted(byKeyPath: "signedInAt", ascending: false).first
    }
    
    // MARK: - Delete All Users
    func deleteAllUsers() {
        guard let realm = realm else { return }
        do {
            try realm.write {
                realm.deleteAll()
            }
            print("Deleted all users from Realm")
        } catch {
            print("Error deleting users: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Profile Management
    
    func saveProfile(_ profile: UserProfile) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(profile, update: .modified)
            }
            print("Saved profile: \(profile.name) (version \(profile.version))")
        } catch {
            print("❌ Error saving profile: \(error.localizedDescription)")
        }
    }
    
    func fetchLatestProfile(for userId: String) -> UserProfile? {
        guard let realm = realm else { return nil }
        return realm.objects(UserProfile.self)
            .filter("userId == %@", userId)
            .sorted(byKeyPath: "updatedAt", ascending: false)
            .first
    }
    
    func fetchAllProfiles(for userId: String) -> [UserProfile] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(UserProfile.self)
            .filter("userId == %@", userId)
            .sorted(byKeyPath: "updatedAt", ascending: false))
    }
    
    // MARK: - Trust Baseline Management (PRIMARY)
    
    func saveBaseline(_ baseline: TrustBaseline) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(baseline, update: .modified)
            }
            print("✅ Saved PRIMARY baseline for user: \(baseline.userId)")
        } catch {
            print("❌ Error saving baseline: \(error.localizedDescription)")
        }
    }
    
    func fetchBaseline(for userId: String) -> TrustBaseline? {
        guard let realm = realm else { return nil }
        return realm.objects(TrustBaseline.self)
            .filter("userId == %@", userId)
            .first
    }
    
    // MARK: - Secondary Device Baseline Management
    
    func saveSecondaryBaseline(_ baseline: SecondaryDeviceBaseline) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(baseline, update: .modified)
            }
            print("✅ Saved SECONDARY baseline: \(baseline.userId) - Device: \(String(baseline.deviceId.prefix(8)))...")
        } catch {
            print("❌ Error saving secondary baseline: \(error.localizedDescription)")
        }
    }
    
    func fetchSecondaryBaseline(userId: String, deviceId: String) -> SecondaryDeviceBaseline? {
        guard let realm = realm else { return nil }
        return realm.objects(SecondaryDeviceBaseline.self)
            .filter("userId == %@ AND deviceId == %@", userId, deviceId)
            .first
    }
    
    func fetchAllSecondaryBaselines(for userId: String) -> [SecondaryDeviceBaseline] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(SecondaryDeviceBaseline.self)
            .filter("userId == %@", userId))
    }
    
    // MARK: - Secondary Device Snapshot Management
    
    func saveSecondarySnapshot(_ snapshot: SecondaryDeviceSnapshot) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(snapshot, update: .modified)
            }
            print("✅ Saved SECONDARY snapshot: Device \(String(snapshot.deviceId.prefix(8)))... - Score: \(snapshot.trustLevel)")
        } catch {
            print("❌ Error saving secondary snapshot: \(error.localizedDescription)")
        }
    }
    
    func fetchSecondarySnapshots(userId: String, deviceId: String) -> [SecondaryDeviceSnapshot] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(SecondaryDeviceSnapshot.self)
            .filter("userId == %@ AND deviceId == %@", userId, deviceId)
            .sorted(byKeyPath: "timestamp", ascending: false))
    }
    
    func fetchAllSecondarySnapshots(for userId: String) -> [SecondaryDeviceSnapshot] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(SecondaryDeviceSnapshot.self)
            .filter("userId == %@", userId)
            .sorted(byKeyPath: "timestamp", ascending: false))
    }
    
    // MARK: - ✅ NEW: Attribute Baseline Management
    
    func saveAttributeBaseline(_ baseline: AttributeBaseline) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(baseline, update: .modified)
            }
            print("✅ Saved AttributeBaseline for user: \(baseline.userId)")
        } catch {
            print("❌ Error saving attribute baseline: \(error.localizedDescription)")
        }
    }
    
    func fetchAttributeBaseline(userId: String, deviceId: String) -> AttributeBaseline? {
        guard let realm = realm else { return nil }
        return realm.objects(AttributeBaseline.self)
            .filter("userId == %@ AND deviceId == %@", userId, deviceId)
            .first
    }
    
    // MARK: - ✅ NEW: Decay Snapshot Management
    
    func saveDecaySnapshot(_ snapshot: DecaySnapshot) {
        guard let realm = realm else {
            print("Realm not initialized")
            return
        }
        
        do {
            try realm.write {
                realm.add(snapshot, update: .modified)
            }
            print("✅ Saved DecaySnapshot: Decay=\(snapshot.decayAmount), Severity=\(snapshot.severity)")
        } catch {
            print("❌ Error saving decay snapshot: \(error.localizedDescription)")
        }
    }
    
    func fetchDecaySnapshots(for userId: String, limit: Int = 10) -> [DecaySnapshot] {
        guard let realm = realm else { return [] }
        return Array(realm.objects(DecaySnapshot.self)
            .filter("userId == %@", userId)
            .sorted(byKeyPath: "timestamp", ascending: false)
            .prefix(limit))
    }
    
    func fetchLatestDecaySnapshot(for userId: String, deviceId: String) -> DecaySnapshot? {
        guard let realm = realm else { return nil }
        return realm.objects(DecaySnapshot.self)
            .filter("userId == %@ AND deviceId == %@", userId, deviceId)
            .sorted(byKeyPath: "timestamp", ascending: false)
            .first
    }
}
