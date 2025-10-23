//
//  NetworkManager.swift
//  UserApp
//
//  Created by Ri on 7/29/25.
//

import Foundation

// Define the expected response structure from the server
struct TrustValidationResponse: Codable {
    let status: String
    let message: String
}

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    private let baseURL = "https://www.ritamonline.org"  // Replace with your actual endpoint

    func validateTrust(userId: String, trustScore: Int, completion: @escaping (Result<TrustValidationResponse, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/validateTrust")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userId": userId,
            "trustScore": trustScore
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let noDataError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received from server"])
                completion(.failure(noDataError))
                return
            }

            do {
                let decodedResponse = try JSONDecoder().decode(TrustValidationResponse.self, from: data)
                completion(.success(decodedResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
