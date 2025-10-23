import Foundation

class TrustScoreManager {
    static let shared = TrustScoreManager()
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    
    private init() {}
    
    // Trust score thresholds
    private let LOW_TRUST_THRESHOLD: Double = 50.0
    private let CRITICAL_TRUST_THRESHOLD: Double = 30.0
    
    // Check if user needs security verification
    func shouldTriggerSecurityVerification(for userId: String, completion: @escaping (Bool, Double?) -> Void) {
        getCurrentTrustScore(for: userId) { trustScore in
            if let score = trustScore {
                let needsVerification = score <= self.LOW_TRUST_THRESHOLD
                completion(needsVerification, score)
            } else {
                // If we can't get trust score, assume verification needed for safety
                completion(true, nil)
            }
        }
    }
    
    // Get actual trust score from your backend
    private func getCurrentTrustScore(for userId: String, completion: @escaping (Double?) -> Void) {
        // Use your actual trust status endpoint
        guard let url = URL(string: "\(baseURL)/security/status/\(userId)") else {
            print("âŒ Invalid trust score URL")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("âŒ Trust score request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("âŒ No trust score data received")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let trustScore = json["trust_score"] as? Double {
                    print("ðŸ“Š Real trust score for user \(userId): \(trustScore)")
                    completion(trustScore)
                } else {
                    print("âŒ Invalid trust score response format")
                    // FALLBACK: For testing, use simulated low score sometimes
                    let simulatedScore = Double.random(in: 20...80)
                    print("ðŸŽ¯ Fallback simulated trust score: \(simulatedScore)")
                    completion(simulatedScore)
                }
            } catch {
                print("âŒ Error parsing trust score: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    // Get user's stored security question
    func getUserSecurityQuestion(userId: String, completion: @escaping (Result<StoredSecurityQuestion, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/security/user-question/\(userId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("ðŸ” Get question response: \(responseString)")
            }
            
            do {
                let question = try JSONDecoder().decode(StoredSecurityQuestion.self, from: data)
                completion(.success(question))
            } catch {
                print("âŒ Decode error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // FIXED: Verify user's answer against stored answer
    func verifySecurityAnswer(userId: String, answer: String, firebaseToken: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/security/verify-stored") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        // âœ… FIXED: Match your backend VerifyStoredAnswerRequest structure
        let body: [String: Any] = [
            "user_id": userId,
            "firebase_token": firebaseToken,
            "user_answer": answer
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(APIError.encodingFailed))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("ðŸ“¤ Verify answer request: \(String(data: jsonData, encoding: .utf8) ?? "")")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("âœ… Verify response code: \(httpResponse.statusCode)")
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("ðŸŒ Verify response: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 {
                    // âœ… FIXED: Parse the actual response body to check "verified" field
                    if let data = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let verified = json["verified"] as? Bool {
                                print("ðŸ” Verification result: \(verified)")
                                completion(.success(verified))
                            } else {
                                print("âŒ Could not parse verification response")
                                completion(.failure(APIError.decodingFailed))
                            }
                        } catch {
                            print("âŒ JSON parsing error: \(error)")
                            completion(.failure(error))
                        }
                    } else {
                        completion(.failure(APIError.noData))
                    }
                } else {
                    // HTTP error - treat as verification failed
                    completion(.success(false))
                }
            }
        }.resume()
    }
}

// MARK: - Models
struct StoredSecurityQuestion: Codable {
    let question: String        // Maps to "question" from your backend
    let hint: String           // Maps to "hint" from your backend
    let userId: String         // Maps to "user_id" from your backend
    
    enum CodingKeys: String, CodingKey {
        case question = "question"
        case hint = "hint"
        case userId = "user_id"
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .encodingFailed:
            return "Failed to encode request"
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}
