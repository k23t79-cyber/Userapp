//
//  FirebaseAppCheckHelper.swift
//  Userapp
//
//  Helper to get Firebase App Check token for backend verification
//

import Foundation
import FirebaseAppCheck

final class FirebaseAppCheckHelper {
    
    static let shared = FirebaseAppCheckHelper()
    
    private init() {}
    
    /// Get Firebase App Check token (equivalent to Android's getAppCheckToken)
    func getAppCheckToken(forcingRefresh: Bool = false) async -> String? {
        print("🔐 [AppCheck] Requesting token from Firebase App Check...")
        print("   - Force refresh: \(forcingRefresh)")
        
        do {
            let tokenResult = try await AppCheck.appCheck().token(forcingRefresh: forcingRefresh)
            
            print("✅ [AppCheck] Token generated successfully")
            print("   - Token (first 50 chars): \(String(tokenResult.token.prefix(50)))...")
            print("   - Token length: \(tokenResult.token.count) characters")
            
            return tokenResult.token
        } catch {
            print("❌ [AppCheck] Failed to get token")
            print("   - Error: \(error.localizedDescription)")
            print("   - Error code: \((error as NSError).code)")
            return nil
        }
    }
    
    /// Get App Check token with completion handler (for non-async contexts)
    func getAppCheckToken(forcingRefresh: Bool = false, completion: @escaping (String?) -> Void) {
        Task {
            let token = await getAppCheckToken(forcingRefresh: forcingRefresh)
            completion(token)
        }
    }
    
    /// Get limited-use token (for one-time backend verification)
    func getLimitedUseToken() async -> String? {
        print("🔐 [AppCheck] Requesting limited-use token...")
        
        do {
            let tokenResult = try await AppCheck.appCheck().limitedUseToken()
            
            print("✅ [AppCheck] Limited-use token generated")
            print("   - Token (first 50 chars): \(String(tokenResult.token.prefix(50)))...")
            
            return tokenResult.token
        } catch {
            print("❌ [AppCheck] Failed to get limited-use token")
            print("   - Error: \(error.localizedDescription)")
            return nil
        }
    }
}
