//
//  Phase2Models.swift
//  Userapp
//

import Foundation

struct Thread1KeyGenerationResult {
    let keyId: String?
    let duration: Double
    let success: Bool
}

struct Thread2AttestationResult {
    let attestationObject: Data?
    let certificateChain: [String]
    let clientDataHash: String
    let duration: Double
    let success: Bool
    let parsedData: ParsedAttestationData?
}

struct Thread3SecurityCheckResult {
    let jailbreakDetected: Bool
    let suspiciousIndicators: [String]
    let confidenceLevel: Int
    let duration: Double
    let details: JailbreakDetectionResult
}

struct ParsedAttestationData {
    let certificateChain: [String]
    let iosVersion: String
    let buildVersion: String
    let secureEnclaveGeneration: String
    let biometricType: String
    let bootState: BootState
    let codeSigningValid: Bool?
    let systemIntegrityProtection: Bool
}

enum BootState: String, Codable {
    case verified = "VERIFIED"
    case unverified = "UNVERIFIED"
    case selfSigned = "SELF_SIGNED"
    case pending = "PENDING"
}

struct SecureEnclaveResponse: Codable {
    let appAttestAttestation: AppAttestAttestation
    let deviceIntegrity: DeviceIntegrity
    let iosSecurityState: IOSSecurityState
    let jailbreakAnalysis: JailbreakAnalysis
    let trustScore: Int
    let processingTime: Int
    let thread1Duration: Int
    let thread2Duration: Int
    let thread3Duration: Int
}

struct AppAttestAttestation: Codable {
    let keyId: String?
    let attestationObject: Data?
    let certificateChain: [String]
    let clientDataHash: String?
}

struct DeviceIntegrity: Codable {
    let secureBootVerified: Bool
    let codeSigningValid: Bool
    let systemIntegrityProtection: Bool
    let noJailbreakDetected: Bool
}

struct IOSSecurityState: Codable {
    let iosVersion: String
    let buildVersion: String
    let secureEnclaveGeneration: String
    let biometricType: String
}

struct JailbreakAnalysis: Codable {
    let detected: Bool
    let suspiciousIndicators: [String]
    let confidenceLevel: Int
}
