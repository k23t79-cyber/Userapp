import Foundation
import RealmSwift

class UserActionQueue: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var actionId: String = "" // Firebase document ID
    @Persisted var userId: String = ""
    @Persisted var deviceId: String = ""
    @Persisted var actionType: String = ""
    @Persisted var payloadJSON: String = "" // JSON string
    @Persisted var syncStatus: String = "PENDING" // PENDING, SYNCED, FAILED
    @Persisted var createdAt: Date = Date()
    
    convenience init(userId: String, deviceId: String, actionType: String, payload: [String: Any]) {
        self.init()
        self.userId = userId
        self.deviceId = deviceId
        self.actionType = actionType
        
        // Convert payload to JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.payloadJSON = jsonString
        }
    }
    
    // Helper to get payload as dictionary
    var payload: [String: Any] {
        guard let data = payloadJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    // Add this method that ActivityFeedViewController is looking for
    func getPayloadDict() -> [String: Any] {
        return payload
    }
}
