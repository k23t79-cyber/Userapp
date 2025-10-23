//
//  IPFetcher.swift
//  Userapp
//
//  Created by Ri on 7/28/25.
//


import Foundation

class IPFetcher {
    static func getPublicIPAddress(completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.ipify.org?format=text") else {
            completion("unknown")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion("unknown")
                return
            }
            let ip = String(data: data, encoding: .utf8) ?? "unknown"
            completion(ip)
        }.resume()
    }
}
