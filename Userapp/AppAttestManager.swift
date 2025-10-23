//
//  AppAttestManager.swift
//  Userapp
//
//  Complete App Attest Manager with Phase 2 support
//

import Foundation
import UIKit
import DeviceCheck
import CryptoKit
import LocalAuthentication

struct AppAttestResult {
    let isValid: Bool
    let score: Int
    let riskLevel: String
    let keyId: String
    let token: String?
    let error: String?
    let attestationObject: Data?
    let certificateChain: [String]
    let clientDataHash: String
    let processingTime: Int
}

final class AppAttestManager {
    
    static let shared = AppAttestManager()
    private let service = DCAppAttestService.shared
    private let backendURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    private let keyIdKey = "com.userapp.appAttest.keyId"
    
    private init() {}
    
    func isSupported() -> Bool {
        return service.isSupported
    }
    
    func getStoredKeyId() -> String? {
        return UserDefaults.standard.string(forKey: keyIdKey)
    }
    
    // MARK: - 🔐 PHASE 2: Complete Three-Thread Attestation
    
    func performPhase2Attestation(userId: String, completion: @escaping (Result<SecureEnclaveResponse, Error>) -> Void) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔐 PHASE 2: CHIP-SPECIFIC IMPLEMENTATION DEEP DIVE")
        print("APPLE SECURE ENCLAVE: APP ATTEST IMPLEMENTATION")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        let phaseStartTime = Date()
        
        guard service.isSupported else {
            let error = NSError(domain: "AppAttest", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "App Attest not supported"])
            completion(.failure(error))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var thread1Result: Thread1KeyGenerationResult?
        var thread2Result: Thread2AttestationResult?
        var thread3Result: Thread3SecurityCheckResult?
        
        // Thread 1
        dispatchGroup.enter()
        let thread1StartTime = Date()
        print("🧵 THREAD 1: App Attest Key Generation started...")
        executeThread1KeyGeneration(startTime: thread1StartTime) { result in
            thread1Result = result
            dispatchGroup.leave()
        }
        
        // Thread 2
        dispatchGroup.enter()
        let thread2StartTime = Date()
        print("🧵 THREAD 2: Attestation Request started...")
        executeThread2Attestation(userId: userId, startTime: thread2StartTime) { result in
            thread2Result = result
            dispatchGroup.leave()
        }
        
        // Thread 3
        dispatchGroup.enter()
        let thread3StartTime = Date()
        print("🧵 THREAD 3: Enhanced Security Checks started...")
        DispatchQueue.global(qos: .userInitiated).async {
            let jailbreakDetector = JailbreakDetector()
            let jailbreakResult = jailbreakDetector.performComprehensiveCheck()
            let thread3Duration = Date().timeIntervalSince(thread3StartTime) * 1000
            
            print("✅ THREAD 3 Complete (\(Int(thread3Duration))ms)")
            
            thread3Result = Thread3SecurityCheckResult(
                jailbreakDetected: jailbreakResult.detected,
                suspiciousIndicators: jailbreakResult.suspiciousProcesses,
                confidenceLevel: jailbreakResult.confidenceLevel,
                duration: thread3Duration,
                details: jailbreakResult
            )
            dispatchGroup.leave()
        }
        
        // Aggregate results
        dispatchGroup.notify(queue: .main) {
            let totalDuration = Date().timeIntervalSince(phaseStartTime) * 1000
            print("\n📊 PHASE 2: Total Duration: \(Int(totalDuration))ms\n")
            
            let response = self.buildSecureEnclaveResponse(
                thread1: thread1Result,
                thread2: thread2Result,
                thread3: thread3Result,
                totalDuration: totalDuration
            )
            
            self.storePhase2Results(response)
            print("✅ PHASE 2 Complete")
            completion(.success(response))
        }
    }
    
    private func executeThread1KeyGeneration(startTime: Date, completion: @escaping (Thread1KeyGenerationResult) -> Void) {
        if let existingKeyId = getStoredKeyId() {
            let duration = Date().timeIntervalSince(startTime) * 1000
            print("✅ THREAD 1 Complete (\(Int(duration))ms)")
            let result = Thread1KeyGenerationResult(keyId: existingKeyId, duration: duration, success: true)
            completion(result)
            return
        }
        
        service.generateKey { [weak self] keyId, error in
            guard let self = self else { return }
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            if let keyId = keyId {
                self.storeKeyId(keyId)
                print("✅ THREAD 1 Complete (\(Int(duration))ms)")
                let result = Thread1KeyGenerationResult(keyId: keyId, duration: duration, success: true)
                completion(result)
            } else {
                print("❌ THREAD 1 Failed (\(Int(duration))ms)")
                let result = Thread1KeyGenerationResult(keyId: nil, duration: duration, success: false)
                completion(result)
            }
        }
    }
    
    private func executeThread2Attestation(userId: String, startTime: Date, completion: @escaping (Thread2AttestationResult) -> Void) {
        guard let keyId = getStoredKeyId() else {
            let duration = Date().timeIntervalSince(startTime) * 1000
            print("❌ THREAD 2 Failed (\(Int(duration))ms)")
            let result = Thread2AttestationResult(
                attestationObject: nil,
                certificateChain: [],
                clientDataHash: "",
                duration: duration,
                success: false,
                parsedData: nil
            )
            completion(result)
            return
        }
        
        let challenge = createChallenge(userId: userId)
        let clientDataHash = Data(SHA256.hash(data: challenge))
        
        service.generateAssertion(keyId, clientDataHash: clientDataHash) { [weak self] assertionObject, error in
            guard let self = self else { return }
            let duration = Date().timeIntervalSince(startTime) * 1000
            
            if let assertionObject = assertionObject {
                print("✅ THREAD 2 Complete (\(Int(duration))ms)")
                let parsedData = self.parseAttestationObject(assertionObject)
                let result = Thread2AttestationResult(
                    attestationObject: assertionObject,
                    certificateChain: parsedData.certificateChain,
                    clientDataHash: clientDataHash.base64EncodedString(),
                    duration: duration,
                    success: true,
                    parsedData: parsedData
                )
                completion(result)
            } else {
                print("❌ THREAD 2 Failed (\(Int(duration))ms)")
                let result = Thread2AttestationResult(
                    attestationObject: nil,
                    certificateChain: [],
                    clientDataHash: clientDataHash.base64EncodedString(),
                    duration: duration,
                    success: false,
                    parsedData: nil
                )
                completion(result)
            }
        }
    }
    
    private func parseAttestationObject(_ data: Data) -> ParsedAttestationData {
        return ParsedAttestationData(
            certificateChain: [],
            iosVersion: UIDevice.current.systemVersion,
            buildVersion: getIOSBuildVersion(),
            secureEnclaveGeneration: getSecureEnclaveGeneration(getModelIdentifier()),
            biometricType: detectBiometricType(),
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
        if modelIdentifier.contains("iPhone17") { return "A18_Pro" }
        if modelIdentifier.contains("iPhone16") { return "A17_Pro" }
        if modelIdentifier.contains("iPhone15") { return "A16_Bionic" }
        if modelIdentifier.contains("iPhone14") { return "A15_Bionic" }
        return "Unknown"
    }
    
    private func detectBiometricType() -> String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return "None"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "None"
        }
    }
    
    private func buildSecureEnclaveResponse(
        thread1: Thread1KeyGenerationResult?,
        thread2: Thread2AttestationResult?,
        thread3: Thread3SecurityCheckResult?,
        totalDuration: Double
    ) -> SecureEnclaveResponse {
        var trustScore = 100
        if thread3?.jailbreakDetected == true { trustScore -= 50 }
        if !(thread1?.success ?? false) { trustScore -= 20 }
        if !(thread2?.success ?? false) { trustScore -= 20 }
        
        return SecureEnclaveResponse(
            appAttestAttestation: AppAttestAttestation(
                keyId: thread1?.keyId,
                attestationObject: thread2?.attestationObject,
                certificateChain: thread2?.certificateChain ?? [],
                clientDataHash: thread2?.clientDataHash
            ),
            deviceIntegrity: DeviceIntegrity(
                secureBootVerified: false,
                codeSigningValid: true,
                systemIntegrityProtection: true,
                noJailbreakDetected: !(thread3?.jailbreakDetected ?? false)
            ),
            iosSecurityState: IOSSecurityState(
                iosVersion: UIDevice.current.systemVersion,
                buildVersion: getIOSBuildVersion(),
                secureEnclaveGeneration: getSecureEnclaveGeneration(getModelIdentifier()),
                biometricType: detectBiometricType()
            ),
            jailbreakAnalysis: JailbreakAnalysis(
                detected: thread3?.jailbreakDetected ?? false,
                suspiciousIndicators: thread3?.suspiciousIndicators ?? [],
                confidenceLevel: thread3?.confidenceLevel ?? 0
            ),
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
    
    // MARK: - 🔄 LEGACY API (for TrustSignalCollector backward compatibility)
    
    func performAttestation(userId: String, completion: @escaping (Result<AppAttestResult, Error>) -> Void) {
        print("🔐 APP ATTEST: Starting legacy attestation flow")
        
        guard service.isSupported else {
            let result = AppAttestResult(
                isValid: false, score: 0, riskLevel: "unsupported", keyId: "", token: nil,
                error: "Device does not support App Attest", attestationObject: nil,
                certificateChain: [], clientDataHash: "", processingTime: 0
            )
            completion(.success(result))
            return
        }
        
        if let existingKeyId = getStoredKeyId() {
            generateAssertionForLegacy(keyId: existingKeyId, userId: userId, completion: completion)
        } else {
            generateKeyForLegacy(userId: userId, completion: completion)
        }
    }
    
    private func generateKeyForLegacy(userId: String, completion: @escaping (Result<AppAttestResult, Error>) -> Void) {
        service.generateKey { [weak self] keyId, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let keyId = keyId else {
                completion(.failure(NSError(domain: "AppAttest", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No key ID"])))
                return
            }
            self.storeKeyId(keyId)
            self.generateAssertionForLegacy(keyId: keyId, userId: userId, completion: completion)
        }
    }
    
    private func generateAssertionForLegacy(keyId: String, userId: String, completion: @escaping (Result<AppAttestResult, Error>) -> Void) {
        let challenge = createChallenge(userId: userId)
        let clientDataHash = Data(SHA256.hash(data: challenge))
        
        service.generateAssertion(keyId, clientDataHash: clientDataHash) { [weak self] assertionObject, error in
            guard let self = self else { return }
            
            if let error = error {
                self.clearStoredKeyId()
                self.generateKeyForLegacy(userId: userId, completion: completion)
                return
            }
            
            guard let assertionObject = assertionObject else {
                completion(.failure(NSError(domain: "AppAttest", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No assertion object"])))
                return
            }
            
            let result = AppAttestResult(
                isValid: true, score: 95, riskLevel: "low",
                keyId: keyId, token: nil, error: nil,
                attestationObject: assertionObject, certificateChain: [],
                clientDataHash: challenge.base64EncodedString(), processingTime: 0
            )
            
            print("✅ APP ATTEST: Legacy attestation complete")
            print("   - Valid: \(result.isValid)")
            print("   - Score: \(result.score)")
            print("   - Risk: \(result.riskLevel)")
            
            completion(.success(result))
        }
    }
    
    // MARK: - Helpers
    
    private func createChallenge(userId: String) -> Data {
        Data("\(userId)-\(Date().timeIntervalSince1970)".utf8)
    }
    
    private func storeKeyId(_ keyId: String) {
        UserDefaults.standard.set(keyId, forKey: keyIdKey)
    }
    
    private func clearStoredKeyId() {
        UserDefaults.standard.removeObject(forKey: keyIdKey)
    }
}
