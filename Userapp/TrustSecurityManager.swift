import Foundation
import UIKit
import FirebaseAuth

class TrustSecurityManager {
    static let shared = TrustSecurityManager()
    
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Keys for UserDefaults
    private let lastDeviceIDKey = "LastDeviceID"
    private let lastTrustCheckKey = "LastTrustCheck"
    private let deviceTrustScoreKey = "DeviceTrustScore"
    
    private init() {}
    
    // MARK: - Trust Score Checking
    func checkTrustScore(for userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/security/status/\(userId)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Firebase token if available
        if let currentUser = Auth.auth().currentUser {
            currentUser.getIDToken { token, error in
                if let token = token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                self.performTrustCheck(request: request, completion: completion)
            }
        } else {
            performTrustCheck(request: request, completion: completion)
        }
    }
    
    private func performTrustCheck(request: URLRequest, completion: @escaping (Bool, String?) -> Void) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("âŒ Trust check error: \(error)")
                completion(false, "Network error")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false, "Invalid response")
                return
            }
            
            if let trustScore = json["trust_score"] as? Double {
                self.userDefaults.set(trustScore, forKey: self.deviceTrustScoreKey)
                self.userDefaults.set(Date(), forKey: self.lastTrustCheckKey)
                
                // Low trust threshold (you can adjust this)
                let isTrustworthy = trustScore >= 70.0
                completion(isTrustworthy, nil)
            } else {
                completion(false, "No trust score found")
            }
        }.resume()
    }
    
    // MARK: - Device Change Detection
    func hasDeviceChanged() -> Bool {
        let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let lastDeviceID = userDefaults.string(forKey: lastDeviceIDKey)
        
        if lastDeviceID == nil {
            // First time - store device ID
            userDefaults.set(currentDeviceID, forKey: lastDeviceIDKey)
            return false
        }
        
        let deviceChanged = currentDeviceID != lastDeviceID
        if deviceChanged {
            print("ðŸ”„ Device change detected!")
            print("ðŸ”„ Last: \(lastDeviceID ?? "nil")")
            print("ðŸ”„ Current: \(currentDeviceID)")
        }
        
        return deviceChanged
    }
    
    func updateDeviceID() {
        let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        userDefaults.set(currentDeviceID, forKey: lastDeviceIDKey)
    }
    
    // MARK: - Security Verification Flow
    func shouldTriggerSecurityVerification(for userId: String, completion: @escaping (Bool, String) -> Void) {
        // Check 1: Device change
        if hasDeviceChanged() {
            completion(true, "Device change detected")
            return
        }
        
        // Check 2: Trust score
        checkTrustScore(for: userId) { isTrustworthy, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(true, "Trust verification required: \(error)")
                } else if !isTrustworthy {
                    completion(true, "Low trust score detected")
                } else {
                    completion(false, "Trust verified")
                }
            }
        }
    }
    
    // MARK: - Get User's Security Question
    func getUserSecurityQuestion(for userId: String, completion: @escaping (Result<SecurityQuestionData, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/security/user-question/\(userId)") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add Firebase token if available
        if let currentUser = Auth.auth().currentUser {
            currentUser.getIDToken { token, error in
                if let token = token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                self.performQuestionFetch(request: request, completion: completion)
            }
        } else {
            performQuestionFetch(request: request, completion: completion)
        }
    }
    
    private func performQuestionFetch(request: URLRequest, completion: @escaping (Result<SecurityQuestionData, Error>) -> Void) {
        print("ðŸ” === PERFORMING QUESTION FETCH ===")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("âŒ Network error in getUserSecurityQuestion: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("âŒ Invalid HTTP response")
                completion(.failure(NSError(domain: "InvalidResponse", code: -1)))
                return
            }
            
            print("ðŸ“¡ HTTP Status Code: \(httpResponse.statusCode)")
            
            // Check if user has no security question (404 or specific error)
            if httpResponse.statusCode == 404 {
                print("âŒ User has no security question (404)")
                completion(.failure(NSError(domain: "NoSecurityQuestion", code: 404)))
                return
            }
            
            guard let data = data else {
                print("âŒ No data received")
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }
            
            // Log raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("ðŸ“¡ Raw getUserSecurityQuestion response: \(responseString)")
            }
            
            // Check for error responses that return 200 but indicate no question
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let error = json["error"] as? String {
                    print("âŒ Backend error: \(error)")
                    completion(.failure(NSError(domain: "BackendError", code: -1, userInfo: ["error": error])))
                    return
                }
                
                if let success = json["success"] as? Bool, !success {
                    print("âŒ Backend returned success: false")
                    completion(.failure(NSError(domain: "BackendError", code: -1)))
                    return
                }
            }
            
            do {
                let questionData = try JSONDecoder().decode(SecurityQuestionData.self, from: data)
                print("âœ… Successfully decoded security question data")
                completion(.success(questionData))
            } catch {
                print("âŒ Failed to decode security question: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Verify Security Answer
    func verifySecurityAnswer(userId: String, answer: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/security/verify-stored") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "user_id": userId,
            "answer": answer
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }
            
            let success = httpResponse.statusCode == 200
            
            if success {
                // Update device ID and trust status on successful verification
                self.updateDeviceID()
            }
            
            let message = success ? "Verification successful" : "Verification failed"
            completion(success, message)
            
        }.resume()
    }
    
    // MARK: - Trust Reset (After successful verification)
    func resetTrustScore(for userId: String) {
        guard let url = URL(string: "\(baseURL)/security/reset-trust") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["user_id": userId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("ðŸ”„ Trust score reset requested")
        }.resume()
    }
}

// MARK: - Data Models (FIXED to match your backend response)
struct SecurityQuestionData: Codable {
    let questionText: String    // Maps to "question" from backend
    let hint: String?           // Maps to "hint" from backend
    let userId: String          // Maps to "user_id" from backend
    
    enum CodingKeys: String, CodingKey {
        case questionText = "question"    // Backend sends "question"
        case hint                         // Backend sends "hint"
        case userId = "user_id"          // Backend sends "user_id"
    }
}
