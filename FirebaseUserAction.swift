
import Foundation

struct FirebaseUserAction: Codable {
    let id: String
    let user_id: String
    let device_id: String
    let type: String
    let payload: String // JSON string
    let created_at: TimeInterval
    
    // Helper to get payload as dictionary
    var payloadDict: [String: Any] {
        guard let data = payload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
