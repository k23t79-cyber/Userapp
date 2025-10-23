//
//  DeviceType.swift
//  Userapp
//
//  Created by Ri on 10/9/25.
//


import Foundation

enum DeviceType: String, Codable {
    case primary = "PRIMARY"
    case secondary = "SECONDARY"
    case unknown = "UNKNOWN"
    
    var description: String {
        switch self {
        case .primary:
            return "Primary Device"
        case .secondary:
            return "Secondary Device"
        case .unknown:
            return "Unknown Device"
        }
    }
    
    var requiresSecurityVerification: Bool {
        return self == .secondary
    }
    
    var emoji: String {
        switch self {
        case .primary:
            return "📱"
        case .secondary:
            return "💻"
        case .unknown:
            return "❓"
        }
    }
}