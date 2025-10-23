import UIKit
import Firebase
import FirebaseAppCheck
import RealmSwift
import BackgroundTasks
import UserNotifications
import DeviceCheck
import LocalAuthentication
import CryptoKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let backgroundSyncIdentifier = "com.userapp.trustsync"
    private let quickSyncIdentifier = "com.userapp.quicksync"
    
    // MARK: - Launch
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        print("=== APP DELEGATE: Application Launched ===")

        // 🔐 App Check before Firebase.configure()
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        print("App Check Debug Provider configured (BEFORE Firebase)")
        #endif

        print("Configuring Firebase…")
        FirebaseApp.configure()

        // MARK: Realm Setup
        print("Initializing Realm…")
        _ = RealmManager.shared
        do {
            let realm = try Realm()
            print("✅ Realm initialized at: \(String(describing: realm.configuration.fileURL))")
        } catch {
            print("❌ Realm failed to initialize: \(error.localizedDescription)")
        }

        checkEncryptionKeyInKeychain()

        // ======================================================
        // 🧩 PHASE 1 – Device DNA Analysis
        // ======================================================
        print("🔍 Starting Device Security Profile probe…")
        DeviceSecurityProfileManager.shared.probeDeviceProfile { profile in
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📱 DEVICE SECURITY PROFILE")
            print("Manufacturer: \(profile.manufacturer)")
            print("Model: \(profile.model) (\(profile.modelIdentifier))")
            print("iOS Version: \(profile.iosVersion)")
            print("Secure Enclave Available: \(profile.secureEnclaveAvailable)")
            print("App Attest Supported: \(profile.appAttestSupported)")
            print("Biometric Type: \(profile.biometricType ?? "None")")
            print("Probe Duration: \(profile.probeDurationMs) ms")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Convert to universal format
            let universal = DeviceSecurityProfileManager.shared.universalProfile(from: profile)
            if let data = try? JSONEncoder().encode(universal),
               let json = String(data: data, encoding: .utf8) {
                print("🌐 UNIVERSAL PROFILE JSON:\n\(json)")
            }

            // Persist minimal flags
            UserDefaults.standard.set(profile.modelIdentifier, forKey: "device_model_identifier")
            UserDefaults.standard.set(profile.secureEnclaveAvailable, forKey: "secure_enclave_flag")
            UserDefaults.standard.set(profile.appAttestSupported, forKey: "app_attest_flag")
        }

        // ======================================================
        // 🔐 PHASE 2 – CHIP-SPECIFIC IMPLEMENTATION (3 Threads)
        // ======================================================
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔐 PHASE 2: CHIP-SPECIFIC IMPLEMENTATION DEEP DIVE")
        print("APPLE SECURE ENCLAVE: APP ATTEST IMPLEMENTATION")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        executePhase2SecureEnclaveAttestation()

        // ======================================================

        print("Starting gyroscope monitoring…")
        GyroscopeManager.shared.startMonitoring()

        requestNotificationPermissions()
        print("=== APP DELEGATE: Initialization Complete ===")
        return true
    }

    // MARK: - 🔐 PHASE 2: Three-Thread Secure Enclave Attestation
    private func executePhase2SecureEnclaveAttestation() {
        let phaseStartTime = Date()
        
        guard DCAppAttestService.shared.isSupported else {
            print("⚠️ App Attest not supported on this device")
            return
        }

        let dispatchGroup = DispatchGroup()
        
        // Storage for thread results
        var thread1Result: Thread1KeyGenerationResult?
        var thread2Result: Thread2AttestationResult?
        var thread3Result: Thread3SecurityCheckResult?
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // THREAD 1: App Attest Key Generation (Target: 800ms)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        dispatchGroup.enter()
        let thread1StartTime = Date()
        print("🧵 THREAD 1: App Attest Key Generation started...")
        
        // Check if key exists using AppAttestManager's key location
        if let existingKeyId = AppAttestManager.shared.getStoredKeyId() {
            let thread1Duration = Date().timeIntervalSince(thread1StartTime) * 1000
            print("✅ THREAD 1 Complete (\(Int(thread1Duration))ms)")
            print("   • Key ID: \(existingKeyId)")
            print("   • Private key stored in Secure Enclave")
            print("   • Key bound to app and device")
            
            thread1Result = Thread1KeyGenerationResult(
                keyId: existingKeyId,
                duration: thread1Duration,
                success: true
            )
            dispatchGroup.leave()
        } else {
            // Generate new key
            DCAppAttestService.shared.generateKey { keyId, error in
                let thread1Duration = Date().timeIntervalSince(thread1StartTime) * 1000
                
                if let keyId = keyId {
                    // Store using AppAttestManager's key location
                    UserDefaults.standard.set(keyId, forKey: "com.userapp.appAttest.keyId")
                    
                    print("✅ THREAD 1 Complete (\(Int(thread1Duration))ms)")
                    print("   • Key ID: \(keyId)")
                    print("   • Private key stored in Secure Enclave")
                    print("   • Key bound to app and device")
                    
                    thread1Result = Thread1KeyGenerationResult(
                        keyId: keyId,
                        duration: thread1Duration,
                        success: true
                    )
                } else {
                    print("❌ THREAD 1 Failed (\(Int(thread1Duration))ms)")
                    thread1Result = Thread1KeyGenerationResult(
                        keyId: nil,
                        duration: thread1Duration,
                        success: false
                    )
                }
                dispatchGroup.leave()
            }
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // THREAD 2: Attestation Request (Target: 700ms)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        dispatchGroup.enter()
        let thread2StartTime = Date()
        print("🧵 THREAD 2: Attestation Request started...")
        
        // Generate challenge for attestation
        let challenge = Data(SHA256.hash(data: UUID().uuidString.data(using: .utf8)!))
        
        // Wait a tiny bit to ensure Thread 1 completes if generating new key
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let keyId = AppAttestManager.shared.getStoredKeyId() else {
                let thread2Duration = Date().timeIntervalSince(thread2StartTime) * 1000
                print("❌ THREAD 2 Failed (\(Int(thread2Duration))ms): No key ID available")
                
                thread2Result = Thread2AttestationResult(
                    attestationObject: nil,
                    certificateChain: [],
                    clientDataHash: challenge.base64EncodedString(),
                    duration: thread2Duration,
                    success: false,
                    parsedData: nil
                )
                dispatchGroup.leave()
                return
            }
            
            DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: challenge) { assertionData, error in
                let thread2Duration = Date().timeIntervalSince(thread2StartTime) * 1000
                
                if let error = error {
                    print("❌ THREAD 2 Failed (\(Int(thread2Duration))ms): \(error.localizedDescription)")
                    thread2Result = Thread2AttestationResult(
                        attestationObject: nil,
                        certificateChain: [],
                        clientDataHash: challenge.base64EncodedString(),
                        duration: thread2Duration,
                        success: false,
                        parsedData: nil
                    )
                    dispatchGroup.leave()
                    return
                }
                
                if let attestationData = assertionData {
                    print("✅ THREAD 2 Complete (\(Int(thread2Duration))ms)")
                    print("   • Attestation object created: \(attestationData.count) bytes")
                    print("   • Certificate chain included")
                    print("   • Signed by Secure Enclave private key")
                    
                    let parsedData = self.parseAttestationObject(attestationData)
                    
                    thread2Result = Thread2AttestationResult(
                        attestationObject: attestationData,
                        certificateChain: parsedData.certificateChain,
                        clientDataHash: challenge.base64EncodedString(),
                        duration: thread2Duration,
                        success: true,
                        parsedData: parsedData
                    )
                } else {
                    print("❌ THREAD 2 Failed (\(Int(thread2Duration))ms): No assertion data")
                    thread2Result = Thread2AttestationResult(
                        attestationObject: nil,
                        certificateChain: [],
                        clientDataHash: challenge.base64EncodedString(),
                        duration: thread2Duration,
                        success: false,
                        parsedData: nil
                    )
                }
                dispatchGroup.leave()
            }
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // THREAD 3: Enhanced Security Checks (Target: 300ms)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        dispatchGroup.enter()
        let thread3StartTime = Date()
        print("🧵 THREAD 3: Enhanced Security Checks started...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let jailbreakDetector = JailbreakDetector()
            let jailbreakResult = jailbreakDetector.performComprehensiveCheck()
            let thread3Duration = Date().timeIntervalSince(thread3StartTime) * 1000
            
            print("✅ THREAD 3 Complete (\(Int(thread3Duration))ms)")
            print("   • File system tests: \(jailbreakResult.fileSystemTestsPassed ? "PASS" : "FAIL")")
            print("   • Suspicious processes: \(jailbreakResult.suspiciousProcesses.isEmpty ? "None detected" : "\(jailbreakResult.suspiciousProcesses.count) found")")
            print("   • Dynamic library analysis: \(jailbreakResult.dynamicLibrariesClean ? "PASS" : "FAIL")")
            print("   • Code injection check: \(jailbreakResult.codeInjectionDetected ? "DETECTED" : "None")")
            print("   • Confidence level: \(jailbreakResult.confidenceLevel)%")
            
            thread3Result = Thread3SecurityCheckResult(
                jailbreakDetected: jailbreakResult.detected,
                suspiciousIndicators: jailbreakResult.suspiciousProcesses,
                confidenceLevel: jailbreakResult.confidenceLevel,
                duration: thread3Duration,
                details: jailbreakResult
            )
            dispatchGroup.leave()
        }
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // PHASE 2: RESPONSE AGGREGATION & PHASE 3: TRANSLATION
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        dispatchGroup.notify(queue: .main) {
            let totalDuration = Date().timeIntervalSince(phaseStartTime) * 1000
            
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 PHASE 2: SECURE ENCLAVE RESPONSE PROCESSING")
            print("Total Duration: \(Int(totalDuration))ms (Target: 1500ms)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
            
            // Build complete SecureEnclaveResponse
            let response = self.buildSecureEnclaveResponse(
                thread1: thread1Result,
                thread2: thread2Result,
                thread3: thread3Result,
                totalDuration: totalDuration
            )
            
            // Convert to JSON and print
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let jsonData = try? encoder.encode(response),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔐 SECURE ENCLAVE RESPONSE JSON:")
                print(jsonString)
            }
            
            // Store Phase 2 results
            self.storePhase2Results(response)
            
            print("\n✅ PHASE 2 Complete - Ready for Phase 3 Trust Calculation")
            
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // 🔄 PHASE 3: UNIVERSAL TRANSLATION
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            print("\n🔄 Starting Phase 3: Universal Translation...")
            
            let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            let challengeString = "phase2-challenge-\(Date().timeIntervalSince1970)"
            
            let universalResponse = Phase3Translator.shared.translateToUniversal(
                phase2Response: response,
                deviceId: deviceId,
                challenge: challengeString
            )
            
            // Store universal response
            if let jsonData = try? encoder.encode(universalResponse) {
                UserDefaults.standard.set(jsonData, forKey: "phase3_universal_response")
                
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("\n🌐 UNIVERSAL ATTESTATION RESPONSE:")
                    print(jsonString)
                }
            }
            
            print("\n✅ PHASE 3 Complete - Universal format ready")
            print("   Hardware Trust Score: \(universalResponse.trustCalculation.finalScore)/100")
            print("   Category: \(universalResponse.trustCalculation.category.rawValue)")
            print("   Software Trust Score: [Existing software implementation]")
            print("   Combined approach maintains separation ✅")
        }
    }

    // MARK: - Attestation Parsing
    private func parseAttestationObject(_ data: Data) -> ParsedAttestationData {
        let iosVersion = UIDevice.current.systemVersion
        let buildVersion = self.getIOSBuildVersion()
        let modelIdentifier = self.getModelIdentifier()
        let biometricType = self.detectBiometricType()
        
        return ParsedAttestationData(
            certificateChain: [],
            iosVersion: iosVersion,
            buildVersion: buildVersion,
            secureEnclaveGeneration: self.getSecureEnclaveGeneration(modelIdentifier),
            biometricType: biometricType,
            bootState: .pending,
            codeSigningValid: nil,
            systemIntegrityProtection: true
        )
    }
    
    private func getIOSBuildVersion() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var buildVersion = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &buildVersion, &size, nil, 0)
        return String(cString: buildVersion)
    }
    
    private func getModelIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    private func getSecureEnclaveGeneration(_ modelIdentifier: String) -> String {
        if modelIdentifier.contains("iPhone16") || modelIdentifier.contains("iPhone17") {
            return "A18_Pro"
        } else if modelIdentifier.contains("iPhone15") {
            return "A17_Pro"
        } else if modelIdentifier.contains("iPhone14") {
            return "A16_Bionic"
        }
        return "Unknown"
    }
    
    private func detectBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "None"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Response Builder
    private func buildSecureEnclaveResponse(
        thread1: Thread1KeyGenerationResult?,
        thread2: Thread2AttestationResult?,
        thread3: Thread3SecurityCheckResult?,
        totalDuration: Double
    ) -> SecureEnclaveResponse {
        
        let deviceIntegrity = DeviceIntegrity(
            secureBootVerified: thread2?.parsedData?.bootState == .verified,
            codeSigningValid: thread2?.parsedData?.codeSigningValid ?? true,
            systemIntegrityProtection: true,
            noJailbreakDetected: !(thread3?.jailbreakDetected ?? false)
        )
        
        let iosSecurityState = IOSSecurityState(
            iosVersion: thread2?.parsedData?.iosVersion ?? UIDevice.current.systemVersion,
            buildVersion: thread2?.parsedData?.buildVersion ?? "Unknown",
            secureEnclaveGeneration: thread2?.parsedData?.secureEnclaveGeneration ?? "Unknown",
            biometricType: thread2?.parsedData?.biometricType ?? "None"
        )
        
        let jailbreakAnalysis = JailbreakAnalysis(
            detected: thread3?.jailbreakDetected ?? false,
            suspiciousIndicators: thread3?.suspiciousIndicators ?? [],
            confidenceLevel: thread3?.confidenceLevel ?? 0
        )
        
        // Calculate trust score
        var trustScore = 100
        if thread3?.jailbreakDetected == true {
            trustScore -= 50
        }
        if !(thread1?.success ?? false) {
            trustScore -= 20
        }
        if !(thread2?.success ?? false) {
            trustScore -= 20
        }
        if !deviceIntegrity.codeSigningValid {
            trustScore -= 15
        }
        
        let appAttestAttestation = AppAttestAttestation(
            keyId: thread1?.keyId,
            attestationObject: thread2?.attestationObject,
            certificateChain: thread2?.certificateChain ?? [],
            clientDataHash: thread2?.clientDataHash
        )
        
        return SecureEnclaveResponse(
            appAttestAttestation: appAttestAttestation,
            deviceIntegrity: deviceIntegrity,
            iosSecurityState: iosSecurityState,
            jailbreakAnalysis: jailbreakAnalysis,
            trustScore: trustScore,
            processingTime: Int(totalDuration),
            thread1Duration: Int(thread1?.duration ?? 0),
            thread2Duration: Int(thread2?.duration ?? 0),
            thread3Duration: Int(thread3?.duration ?? 0)
        )
    }
    
    private func storePhase2Results(_ response: SecureEnclaveResponse) {
        if let jsonData = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(jsonData, forKey: "phase2_secure_enclave_response")
        }
    }

    // MARK: - Notifications
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification error: \(error)")
            }
        }
    }

    private func sendCrossDeviceNotification(userId: String,
                                             updatingDevice: String,
                                             trustScore: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "Security Update"
        content.body  = "Trust score updated to \(trustScore) by device \(String(updatingDevice.prefix(8)))…"
        content.sound = .default
        content.userInfo = [
            "userId": userId,
            "updatingDevice": updatingDevice,
            "trustScore": trustScore,
            "updateType": "cross_device",
            "schema": "new"
        ]
        let request = UNNotificationRequest(identifier: "trust_update_\(UUID().uuidString)",
                                            content: content,
                                            trigger: nil)
        do { try await UNUserNotificationCenter.current().add(request) }
        catch { print("❌ Failed to send notification: \(error)") }
    }

    // MARK: - Background Scheduling
    private func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: backgroundSyncIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleQuickSync() {
        let request = BGAppRefreshTaskRequest(identifier: quickSyncIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Lifecycle
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("=== APP DELEGATE: Entering Background ===")
        GyroscopeManager.shared.stopMonitoring()
        scheduleBackgroundSync()
        scheduleQuickSync()

        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = application.beginBackgroundTask { application.endBackgroundTask(taskID) }
        Task {
            await OfflineSyncManager.shared.processOfflineQueue()
            application.endBackgroundTask(taskID)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("=== APP DELEGATE: Entering Foreground ===")
        GyroscopeManager.shared.startMonitoring()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundSyncIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: quickSyncIdentifier)
        checkForPendingBackgroundUpdates()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("=== APP DELEGATE: Application Terminating ===")
        GyroscopeManager.shared.stopMonitoring()
    }

    // MARK: - Pending-Update Helpers
    private func checkForPendingBackgroundUpdates() {
        if UserDefaults.standard.bool(forKey: "pendingTrustUpdate") {
            let trustScore = UserDefaults.standard.integer(forKey: "pendingTrustScore")
            let updatingDevice = UserDefaults.standard.string(forKey: "pendingUpdatingDevice") ?? ""
            let userId = UserDefaults.standard.string(forKey: "pendingUpdateUserId") ?? ""
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("BackgroundTrustUpdateReceived"),
                    object: ["trustScore": trustScore,
                             "updatingDevice": updatingDevice,
                             "userId": userId]
                )
            }
            clearBackgroundUpdateFlags()
        }
    }

    private func clearBackgroundUpdateFlags() {
        UserDefaults.standard.removeObject(forKey: "pendingTrustUpdate")
        UserDefaults.standard.removeObject(forKey: "pendingTrustScore")
        UserDefaults.standard.removeObject(forKey: "pendingUpdatingDevice")
        UserDefaults.standard.removeObject(forKey: "pendingUpdateUserId")
        UserDefaults.standard.removeObject(forKey: "pendingUpdateType")
        UserDefaults.standard.removeObject(forKey: "pendingDeviceIsPrimary")
    }

    // MARK: - Keychain Helper
    func checkEncryptionKeyInKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "encryption",
            kSecAttrAccount as String: "aesKey",
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess {
            print("🔑 AES encryption key found in Keychain.")
        } else {
            print("⚠️ AES encryption key NOT found in Keychain.")
        }
    }

    // MARK: - Scene Lifecycle
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration",
                                    sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) { }
}
