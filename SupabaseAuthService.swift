import Foundation

class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private let supabaseURL = "https://ojhodugbjutzpaguubfh.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

    private init() {}

    func sendOTP(to email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/otp") else {
            completion(false, "Invalid Supabase URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response")
                return
            }

            if httpResponse.statusCode == 200 {
                completion(true, nil)
            } else {
                completion(false, "Status code: \(httpResponse.statusCode)")
            }
        }.resume()
    }
}
