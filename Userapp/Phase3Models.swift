//
//  Phase3Models.swift
//  Userapp
//
//  Phase 3: Universal Attestation Response Models
//

import Foundation

// MARK: - Universal Attestation Response

struct UniversalAttestationResponse: Codable {
    let deviceId: String
    let platform: Platform
    let manufacturer: String
    let model: String
    
    let securityTier: SecurityTier
    let securityChip: String
    let chipGeneration: ChipGeneration
    
    let hardwareAttestation: HardwareAttestation
    let systemIntegrity: SystemIntegrity
    let patchInformation: PatchInformation
    let securityCapabilities: SecurityCapabilities
    let trustCalculation: HardwareTrustCalculation
    let attestationMetadata: AttestationMetadata
}

// MARK: - Enums

enum Platform: String, Codable {
    case iOS = "iOS"
    case android = "ANDROID"
}

enum SecurityTier: String, Codable {
    case tier1DedicatedChip = "TIER_1_DEDICATED_CHIP"
    case tier2SoftwareBacked = "TIER_2_SOFTWARE_BACKED"
    case tier3None = "TIER_3_NONE"
}

enum ChipGeneration: String, Codable {
    case latest = "LATEST"
    case previous = "PREVIOUS"
    case legacy = "LEGACY"
}

enum AttestationMethod: String, Codable {
    case playIntegrity = "PLAY_INTEGRITY"
    case knoxAttest = "KNOX_ATTEST"
    case appAttest = "APP_ATTEST"
}

enum VerificationStatus: String, Codable {
    case pending = "PENDING"
    case valid = "VALID"
    case invalid = "INVALID"
    case failed = "FAILED"
}

enum UniversalBootState: String, Codable {
    case verified = "VERIFIED"
    case unverified = "UNVERIFIED"
    case selfSigned = "SELF_SIGNED"
    case unknown = "UNKNOWN"
}

enum DataReliability: String, Codable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
}

enum PatchCompliance: String, Codable {
    case current = "CURRENT"
    case outdated = "OUTDATED"
    case critical = "CRITICAL"
}

enum BiometricType: String, Codable {
    case faceID = "FACE_ID"
    case touchID = "TOUCH_ID"
    case opticID = "OPTIC_ID"
    case fingerprint = "FINGERPRINT"
    case none = "NONE"
}

enum TrustCategory: String, Codable {
    case fullAccess = "FULL_ACCESS"
    case restricted = "RESTRICTED"
    case limited = "LIMITED"
    case blocked = "BLOCKED"
}

// MARK: - Hardware Attestation

struct HardwareAttestation: Codable {
    let method: AttestationMethod
    let primaryToken: String
    let backupToken: String?
    let verified: VerificationStatus
    let platformSpecific: PlatformSpecificData
}

struct PlatformSpecificData: Codable {
    // iOS Secure Enclave
    let keyId: String?
    let biometricType: BiometricType?
    let secureEnclaveGeneration: String?
    
    // Android Titan M (for future)
    let titanMVersion: String?
    let strongBoxLevel: String?
    
    // Samsung Knox (for future)
    let knoxVersion: String?
    let warrantyBit: String?
    let timaScore: Int?
}

// MARK: - System Integrity

struct SystemIntegrity: Codable {
    let bootState: UniversalBootState  
    let bootloaderLocked: Bool?
    let secureBootEnabled: Bool
    let systemTamperingDetected: Bool
    let bootDataSource: String
    let bootDataReliability: DataReliability
}

// MARK: - Patch Information

struct PatchInformation: Codable {
    let osPatchLevel: String
    let vendorPatchLevel: String?
    let daysSinceLastPatch: Int
    let patchCompliance: PatchCompliance
}

// MARK: - Security Capabilities

struct SecurityCapabilities: Codable {
    let hardwareKeyStorage: Bool
    let biometricAuthentication: BiometricType
    let secureUIAvailable: Bool
    let hardwareAttestationSupported: Bool
    let enterpriseFeatures: EnterpriseFeatures
}

struct EnterpriseFeatures: Codable {
    let workspaceSupport: Bool
    let mdmCompliance: Bool
    let corporateAppSupport: Bool
}

// MARK: - Hardware Trust Calculation

struct HardwareTrustCalculation: Codable {
    let baseScore: Int
    let deductions: [TrustAdjustment]
    let bonuses: [TrustAdjustment]
    let finalScore: Int
    let category: TrustCategory
}

struct TrustAdjustment: Codable {
    let reason: String
    let points: Int
}

// MARK: - Attestation Metadata

struct AttestationMetadata: Codable {
    let timestamp: String
    let processingTime: Int
    let attestationVersion: String
    let challengeUsed: String
}
