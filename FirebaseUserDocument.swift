//
//  FirebaseUserDocument.swift
//  Userapp
//
//  Created by Ri on 10/9/25.
//


import Foundation
import FirebaseFirestore

struct FirebaseUserDocument: Codable {
    let userId: String
    let email: String
    let securitySetupComplete: Bool
    let primaryDeviceId: String?
    let createdAt: Date?
    let securitySetupTimestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId
        case email
        case securitySetupComplete
        case primaryDeviceId
        case createdAt
        case securitySetupTimestamp
    }
    
    var needsSecuritySetup: Bool {
        return !securitySetupComplete
    }
}