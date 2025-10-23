import Foundation

enum TrustStatus: String, Codable {
    case pending = "PENDING"
    case trusted = "TRUSTED"
    case reverifyIdentity = "REVERIFY_IDENTITY"
    case blocked = "BLOCKED"
    case synced = "SYNCED"
    case merged = "MERGED"
    case pendingPrimary = "PENDING_PRIMARY"
    
    var description: String {
        switch self {
        case .pending:
            return "Verification in progress"
        case .trusted:
            return "Device trusted - Access granted"
        case .reverifyIdentity:
            return "Additional verification required"
        case .blocked:
            return "Access denied - Security risk detected"
        case .synced:
            return "Synced to cloud"
        case .merged:
            return "Merged with primary device"
        case .pendingPrimary:
            return "Waiting for primary device approval"
        }
    }
    
    var emoji: String {
        switch self {
        case .pending:
            return "⏳"
        case .trusted:
            return "✅"
        case .reverifyIdentity:
            return "⚠️"
        case .blocked:
            return "🚫"
        case .synced:
            return "☁️"
        case .merged:
            return "🔄"
        case .pendingPrimary:
            return "⏸️"
        }
    }
    
    var isAccessGranted: Bool {
        return self == .trusted || self == .synced || self == .merged
    }
    
    var requiresAction: Bool {
        return self == .reverifyIdentity || self == .blocked || self == .pendingPrimary
    }
}
