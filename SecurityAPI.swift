

import Foundation
import Alamofire

struct SecurityAPI {
    static let baseURL = "https://your-cloud-run-url"  // replace with actual backend URL

    // 1. Save Security Question
    static func setupQuestion(userId: String, questionId: String, answer: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(baseURL)/security/setup"
        let params: [String: Any] = [
            "user_id": userId,
            "question_id": questionId,
            "answer": answer
        ]
        
        AF.request(url, method: .post, parameters: params, encoding: JSONEncoding.default).response { response in
            switch response.result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 2. Get Stored Question
    static func getQuestion(userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = "\(baseURL)/security/user-question/\(userId)"
        
        AF.request(url, method: .get).responseDecodable(of: [String:String].self) { response in
            switch response.result {
            case .success(let data):
                if let question = data["question_text"] {
                    completion(.success(question))
                } else {
                    completion(.failure(NSError(domain: "ParseError", code: -1)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // 3. Verify Answer
    static func verifyAnswer(userId: String, answer: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = "\(baseURL)/security/verify-stored"
        let params: [String: Any] = [
            "user_id": userId,
            "answer": answer
        ]
        
        AF.request(url, method: .post, parameters: params, encoding: JSONEncoding.default).response { response in
            switch response.result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
