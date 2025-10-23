//
//  Phase3Translator.swift
//  Userapp
//
//  Created by Ri on 21/10/25.
//


//
//  Phase3Translator.swift
//  Userapp
//
//  Phase 3: Universal Translation Layer
//  Converts Phase 2 chip-specific responses to universal format
//

import Foundation
import UIKit

final class Phase3Translator {
    
    static let shared = Phase3Translator()
    private let attestationVersion = "2.1.0"
    
    private init() {}
    
    // MARK: - 🔄 Main Translation Method
    
    /// Translate Phase 2 Secure Enclave response to Universal format
    func translateToUniversal(
        phase2Response: SecureEnclaveResponse,
        deviceId: String,
        challenge: String
    ) -> UniversalAttestationResponse {
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 PHASE 3: UNIVERSAL TRANSLATION LAYER")
        print("Converting Secure Enclave response to Universal format")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
        let startTime = Date()
        
        // Get device information
        let deviceInfo = getDeviceInformation()
        
        // Translate each component
        let hardwareAttestation = translateHardwareAttestation(from: phase2Response)
        let systemIntegrity = translateSystemIntegrity(from: phase2Response)
        let patchInfo = translatePatchInformation(from: phase2Response)
        let securityCaps = translateSecurityCapabilities(from: phase2Response)
        let trustCalc = calculateHardwareTrust(from: phase2Response)
        
        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)
        
        let universal = UniversalAttestationResponse(
            deviceId: deviceId,
            platform: .iOS,
            manufacturer: "Apple",
            model: deviceInfo.model,
            securityTier: .tier1DedicatedChip,
            securityChip: "Secure Enclave",
            chipGeneration: getChipGeneration(phase2Response.iosSecurityState.secureEnclaveGeneration),
            hardwareAttestation: hardwareAttestation,
            systemIntegrity: systemIntegrity,
            patchInformation: patchInfo,
            securityCapabilities: securityCaps,
            trustCalculation: trustCalc,
            attestationMetadata: AttestationMetadata(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                processingTime: processingTime,
                attestationVersion: attestationVersion,
                challengeUsed: challenge
            )
        )
        
        print("✅ Translation complete in \(processingTime)ms")
        print("   Hardware Trust Score: \(trustCalc.finalScore)/100")
        print("   Category: \(trustCalc.category.rawValue)")
        
        return universal
    }
    
    // MARK: - Component Translators
    
    private func translateHardwareAttestation(from phase2: SecureEnclaveResponse) -> HardwareAttestation {
        let verified: VerificationStatus
        if phase2.trustScore >= 80 {
            verified = .valid
        } else if phase2.trustScore >= 50 {
            verified = .pending
        } else {
            verified = .invalid
        }
        
        let biometric = mapBiometricType(phase2.iosSecurityState.biometricType)
        
        return HardwareAttestation(
            method: .appAttest,
            primaryToken: phase2.appAttestAttestation.keyId ?? "",
            backupToken: phase2.appAttestAttestation.clientDataHash,
            verified: verified,
            platformSpecific: PlatformSpecificData(
                keyId: phase2.appAttestAttestation.keyId,
                biometricType: biometric,
                secureEnclaveGeneration: phase2.iosSecurityState.secureEnclaveGeneration,
                titanMVersion: nil,
                strongBoxLevel: nil,
                knoxVersion: nil,
                warrantyBit: nil,
                timaScore: nil
            )
        )
    }
    private func translateSystemIntegrity(from phase2: SecureEnclaveResponse) -> SystemIntegrity {
        let bootState: UniversalBootState  // ✅ Correct type
        if phase2.deviceIntegrity.secureBootVerified {
            bootState = .verified
        } else if phase2.deviceIntegrity.codeSigningValid {
            bootState = .selfSigned
        } else {
            bootState = .unverified
        }
        
        let reliability: DataReliability
        if phase2.deviceIntegrity.secureBootVerified && phase2.deviceIntegrity.systemIntegrityProtection {
            reliability = .high
        } else if phase2.deviceIntegrity.codeSigningValid {
            reliability = .medium
        } else {
            reliability = .low
        }
        
        return SystemIntegrity(
            bootState: bootState,
            bootloaderLocked: nil,
            secureBootEnabled: phase2.deviceIntegrity.systemIntegrityProtection,
            systemTamperingDetected: phase2.jailbreakAnalysis.detected,
            bootDataSource: "HARDWARE_VERIFIED",
            bootDataReliability: reliability
        )
    }

    private func translatePatchInformation(from phase2: SecureEnclaveResponse) -> PatchInformation {
        let buildDate = extractBuildDate(phase2.iosSecurityState.buildVersion)
        let daysSince = Calendar.current.dateComponents([.day], from: buildDate, to: Date()).day ?? 0
        
        let compliance: PatchCompliance
        if daysSince <= 30 {
            compliance = .current
        } else if daysSince <= 90 {
            compliance = .outdated
        } else {
            compliance = .critical
        }
        
        return PatchInformation(
            osPatchLevel: phase2.iosSecurityState.iosVersion,
            vendorPatchLevel: phase2.iosSecurityState.buildVersion,
            daysSinceLastPatch: daysSince,
            patchCompliance: compliance
        )
    }
    
    private func translateSecurityCapabilities(from phase2: SecureEnclaveResponse) -> SecurityCapabilities {
        let biometric = mapBiometricType(phase2.iosSecurityState.biometricType)
        
        return SecurityCapabilities(
            hardwareKeyStorage: true, // Always true for Secure Enclave
            biometricAuthentication: biometric,
            secureUIAvailable: true,
            hardwareAttestationSupported: true,
            enterpriseFeatures: EnterpriseFeatures(
                workspaceSupport: false, // iOS doesn't have Knox equivalent
                mdmCompliance: true,
                corporateAppSupport: true
            )
        )
    }
    
    private func calculateHardwareTrust(from phase2: SecureEnclaveResponse) -> HardwareTrustCalculation {
        var deductions: [TrustAdjustment] = []
        var bonuses: [TrustAdjustment] = []
        var baseScore = 100
        
        // Deductions
        if phase2.jailbreakAnalysis.detected {
            deductions.append(TrustAdjustment(
                reason: "Jailbreak detected (confidence: \(phase2.jailbreakAnalysis.confidenceLevel)%)",
                points: -50
            ))
        }
        
        if !phase2.deviceIntegrity.noJailbreakDetected {
            deductions.append(TrustAdjustment(
                reason: "System tampering detected",
                points: -30
            ))
        }
        
        if !phase2.deviceIntegrity.secureBootVerified {
            deductions.append(TrustAdjustment(
                reason: "Secure boot not verified",
                points: -10
            ))
        }
        
        // Check patch level
        let buildDate = extractBuildDate(phase2.iosSecurityState.buildVersion)
        let daysSince = Calendar.current.dateComponents([.day], from: buildDate, to: Date()).day ?? 0
        if daysSince > 90 {
            deductions.append(TrustAdjustment(
                reason: "Security patch outdated (\(daysSince) days old)",
                points: -15
            ))
        }
        
        // Bonuses
        if phase2.iosSecurityState.secureEnclaveGeneration.contains("A18") ||
           phase2.iosSecurityState.secureEnclaveGeneration.contains("A17") {
            bonuses.append(TrustAdjustment(
                reason: "Latest generation security chip",
                points: +5
            ))
        }
        
        if phase2.iosSecurityState.biometricType != "None" {
            bonuses.append(TrustAdjustment(
                reason: "Hardware biometric authentication available",
                points: +3
            ))
        }
        
        // Calculate final score
        let totalDeductions = deductions.reduce(0) { $0 + $1.points }
        let totalBonuses = bonuses.reduce(0) { $0 + $1.points }
        let finalScore = max(0, min(100, baseScore + totalDeductions + totalBonuses))
        
        // Determine category
        let category: TrustCategory
        if finalScore >= 90 {
            category = .fullAccess
        } else if finalScore >= 70 {
            category = .restricted
        } else if finalScore >= 50 {
            category = .limited
        } else {
            category = .blocked
        }
        
        return HardwareTrustCalculation(
            baseScore: baseScore,
            deductions: deductions,
            bonuses: bonuses,
            finalScore: finalScore,
            category: category
        )
    }
    
    // MARK: - Helper Methods
    
    private func getDeviceInformation() -> (model: String, modelId: String) {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let modelId = String(cString: machine)
        
        let model = UIDevice.current.model
        return (model, modelId)
    }
    
    private func getChipGeneration(_ generation: String) -> ChipGeneration {
        if generation.contains("A18") || generation.contains("A17") {
            return .latest
        } else if generation.contains("A16") || generation.contains("A15") {
            return .previous
        } else {
            return .legacy
        }
    }
    
    private func mapBiometricType(_ type: String) -> BiometricType {
        switch type.lowercased() {
        case "face id": return .faceID
        case "touch id": return .touchID
        case "optic id": return .opticID
        default: return .none
        }
    }
    
    private func extractBuildDate(_ buildVersion: String) -> Date {
        // iOS build versions don't encode dates directly
        // Return approximate date based on iOS version
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Approximate: assume current iOS versions are within last 90 days
        return Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date()
    }
}
