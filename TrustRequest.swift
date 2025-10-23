//
//  TrustRequest.swift
//  Userapp
//
//  Created by Ri on 7/30/25.
//


import UIKit

struct TrustRequest: Codable {
    let userId: String
    let trustScore: Int
}

struct TrustResponse: Codable {
    let status: String
    let message: String
}

class TrustValidationViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        performTrustValidation()
    }
    
    private func performTrustValidation() {
        // ✅ Replace with your actual backend endpoint:
        guard let url = URL(string: "https://www.ritamonline.org") else {
            print("Invalid URL")
            return
        }
        
        let requestBody = TrustRequest(userId: "123456", trustScore: 85)

        // Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            print("❌ Error encoding JSON: \(error)")
            return
        }
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ Server error: \(httpResponse.statusCode)")
                if let data = data, let raw = String(data: data, encoding: .utf8) {
                    print("🚨 Raw Server Response:\n\(raw)")
                }
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(TrustResponse.self, from: data)
                print("✅ Status: \(decoded.status) — \(decoded.message)")
            } catch {
                print("❌ JSON Parse Error: \(error)")
                if let raw = String(data: data, encoding: .utf8) {
                    print("🚨 Raw Server Response:\n\(raw)")
                }
            }
        }
        
        task.resume()
    }
}
