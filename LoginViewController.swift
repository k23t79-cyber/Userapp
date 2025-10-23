//
//  LoginViewController.swift
//  Userapp
//

import UIKit
import GoogleSignIn
import FirebaseAuth
import RealmSwift
import AuthenticationServices
import FirebaseCore
import FirebaseFirestore
import SystemConfiguration.CaptiveNetwork
import Network
import CoreLocation

final class LoginViewController: UIViewController,
ASAuthorizationControllerDelegate,
ASAuthorizationControllerPresentationContextProviding {
    
    // MARK: - UI
    private let googleSignInButton = UIButton(type: .system)
    private let appleSignInButton = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
    private let emailSignInButton = UIButton(type: .system)
    
    // MARK: - Config
    private let supabaseURL = "https://ojhodugbjutzpaguubfh.supabase.co"
    private let supabaseAnonKey = ""
    private let questionsAPIURL = "https://firebase-security-backend-514931815167.us-central1.run.app/security/template-questions"
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("=== LOGIN VIEW CONTROLLER: ViewDidLoad Called ===")
        print("Setting up UI and buttons...")
        ensureRealmDirectoryExists()
        view.backgroundColor = .white
        LocationManager.shared.requestLocationAccess()
        setupButtons()
        print("=== LOGIN VIEW CONTROLLER: Setup Complete ===")
    }
    
    // MARK: - UI Setup
    private func setupButtons() {
        googleSignInButton.setTitle("Sign in with Google", for: .normal)
        googleSignInButton.backgroundColor = UIColor(red: 219/255, green: 68/255, blue: 55/255, alpha: 1)
        googleSignInButton.setTitleColor(.white, for: .normal)
        googleSignInButton.layer.cornerRadius = 6
        googleSignInButton.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)
        
        appleSignInButton.addTarget(self, action: #selector(handleAppleSignIn), for: .touchUpInside)
        
        emailSignInButton.setTitle("Sign in with Email", for: .normal)
        emailSignInButton.backgroundColor = .systemBlue
        emailSignInButton.setTitleColor(.white, for: .normal)
        emailSignInButton.layer.cornerRadius = 6
        emailSignInButton.addTarget(self, action: #selector(promptForEmail), for: .touchUpInside)
        
        [googleSignInButton, appleSignInButton, emailSignInButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            googleSignInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            googleSignInButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            googleSignInButton.widthAnchor.constraint(equalToConstant: 220),
            googleSignInButton.heightAnchor.constraint(equalToConstant: 50),
            
            appleSignInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            appleSignInButton.topAnchor.constraint(equalTo: googleSignInButton.bottomAnchor, constant: 20),
            appleSignInButton.widthAnchor.constraint(equalToConstant: 220),
            appleSignInButton.heightAnchor.constraint(equalToConstant: 50),
            
            emailSignInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emailSignInButton.topAnchor.constraint(equalTo: appleSignInButton.bottomAnchor, constant: 30),
            emailSignInButton.widthAnchor.constraint(equalToConstant: 220),
            emailSignInButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
    
    private func ensureRealmDirectoryExists() {
        let fileManager = FileManager.default
        let realmURL = Realm.Configuration.defaultConfiguration.fileURL!
        let folderPath = realmURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: folderPath.path) {
            do {
                try fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true)
                print("Realm folder created at: \(folderPath.path)")
            } catch {
                print("Failed to create Realm directory: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Google Sign-In
    @objc private func handleGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Missing Firebase clientID")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
            if let error = error {
                print("Google Sign-In failed: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Missing Google tokens")
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Auth failed: \(error.localizedDescription)")
                    return
                }
                
                guard let firebaseUser = authResult?.user else { return }
                let name = firebaseUser.displayName ?? "Google User"
                let userId = firebaseUser.uid
                let email = firebaseUser.email ?? ""
                self.handlePostLogin(userId: userId, name: name, email: email, method: "google")
            }
        }
    }
    
    // MARK: - Apple Sign-In
    @objc private func handleAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = credential.user
            let email = credential.email ?? "unknown@apple.com"
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            handlePostLogin(userId: userId, name: name, email: email, method: "apple")
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window!
    }
    
    // MARK: - Email OTP
    @objc private func promptForEmail() {
        let alert = UIAlertController(title: "Sign in with Email", message: "Enter your email address", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Enter email" }
        let sendOTP = UIAlertAction(title: "Send OTP", style: .default) { _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else {
                self.showAlert(title: "Error", message: "Email cannot be empty")
                return
            }
            
            let realm = try! Realm()
            if let existingUser = realm.objects(UserModel.self).filter("email == %@", email).first {
                self.showAlert(title: "Use Original Method", message: "You're already signed in using \(existingUser.method.capitalized).")
                return
            }
            
            self.sendOtpToEmail(email: email)
        }
        alert.addAction(sendOTP)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func sendOtpToEmail(email: String) {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/otp") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        let payload: [String: Any] = ["email": email, "create_user": true]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("OTP Request failed: \(error.localizedDescription)")
                return
            }
            
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("Failed to send OTP")
                return
            }
            
            DispatchQueue.main.async {
                self.showOTPVerificationAlert(for: email)
            }
        }.resume()
    }
    
    private func showOTPVerificationAlert(for email: String) {
        let alert = UIAlertController(title: "Verify OTP", message: "Enter the OTP sent to \(email)", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Enter OTP"; $0.keyboardType = .numberPad }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Verify", style: .default) { _ in
            let otp = alert.textFields?.first?.text ?? ""
            self.verifyOTP(email: email, otp: otp)
        })
        present(alert, animated: true)
    }
    
    private func verifyOTP(email: String, otp: String) {
        guard let url = URL(string: "\(supabaseURL)/auth/v1/verify") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["email": email, "token": otp, "type": "email"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Error", message: "Invalid OTP. Access denied.")
                }
                return
            }
            
            let userId = UUID().uuidString
            self.handlePostLogin(userId: userId, name: email, email: email, method: "email")
        }.resume()
    }
    
    // MARK: - Post Login Logic
    private func handlePostLogin(userId: String, name: String, email: String, method: String) {
        print("=== POST-LOGIN: Starting for \(email) ===")
        print("  UserId: \(userId)")
        print("  Method: \(method)")
        
        if let existingUser = getExistingUser(email: email) {
            print("  Status: EXISTING USER (Returning)")
            print("  Existing UserId: \(existingUser.userId)")
            updateExistingUser(existingUser, with: userId, name: name, method: method)
        } else {
            print("  Status: NEW USER (First Login)")
            print("  Creating fresh account...")
            saveUserToRealm(userId: userId, name: name, email: email, method: method)
            saveUserToFirestore(userId: userId, name: name, email: email, method: method)
            Task {
                await createBaselineForNewUser(userId: userId, email: email)
            }
        }
        
        print("=== POST-LOGIN: Process Complete ===")
        
        // ✅ ALWAYS USE TRUST VERIFIER - Let it handle routing
        print("🔍 Starting TrustVerifier flow...")
        TrustVerifier.shared.verifyUser(userId: userId, email: email) { [weak self] result in
            guard let self = self else { return }
            self.handleVerificationResult(result)
        }
    }
    
    // ✅ CORRECTED: Handle TrustVerifier results properly
    private func handleVerificationResult(_ result: TrustVerifier.VerificationResult) {
        switch result {
        case .requiresSecurityVerification(let userId, let reason):
            print("⚠️ Security verification required: \(reason)")
            // ✅ FIX: Route through SceneDelegate instead of direct navigation
            navigateToSecurityFlow(userId: userId, reason: reason)
            
        case .trusted(let userId):
            print("✅ User trusted - navigating to Home")
            navigateToHome()
            
        case .blocked(let reason):
            print("🚫 User blocked: \(reason)")
            showBlockedAlert(reason: reason)
        }
    }
    
    // ✅ NEW: Proper routing through SceneDelegate
    private func navigateToSecurityFlow(userId: String, reason: String) {
        // Get email from Realm
        guard let email = getExistingUser(userId: userId)?.email else {
            print("❌ Could not find user email")
            return
        }
        
        // Let SceneDelegate handle the routing
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.handleSecurityVerification(userId: userId, email: email, reason: reason)
        }
    }
    
    // Helper to get user by userId
    private func getExistingUser(userId: String) -> UserModel? {
        do {
            let realm = try Realm()
            return realm.objects(UserModel.self).filter("userId == %@", userId).first
        } catch {
            return nil
        }
    }
    
    // Helper method to show blocked alert
    private func showBlockedAlert(reason: String) {
        let alert = UIAlertController(
            title: "🚫 Access Denied",
            message: reason,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            try? Auth.auth().signOut()
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    // ✅ NEW METHOD: Navigate to home
    private func navigateToHome() {
        let homeVC = HomeViewController()
        let navController = UINavigationController(rootViewController: homeVC)
        navController.modalPresentationStyle = .fullScreen
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        } else {
            present(navController, animated: true)
        }
    }
    
    // MARK: - NEW USER FLOW
    private func createBaselineForNewUser(userId: String, email: String) async {
        print("📊 NEW USER: Creating trust baseline...")
        
        TrustSignalCollector.shared.collectSignals(
            userId: userId,
            baseline: nil
        ) { signals in
            print("  ✅ Signals collected: \(signals.toDictionary().keys.joined(separator: ", "))")
            
            self.saveBaselineToRealm(userId: userId, email: email, signalsDict: signals.toDictionary())
            
            print("  🔥 Creating PRIMARY device snapshot...")
            TrustSnapshotManager.shared.saveTrustSnapshot(for: userId, email: email)
        }
    }
    
    // MARK: - BASELINE MANAGEMENT
    private func saveBaselineToRealm(userId: String, email: String, signalsDict: [String: Any]) {
        do {
            let realm = try Realm()
            let baseline = TrustBaseline()
            baseline.userId = userId
            baseline.email = email
            baseline.deviceId = signalsDict["deviceId"] as? String ?? ""
            baseline.systemVersion = signalsDict["systemVersion"] as? String ?? ""
            baseline.timezone = signalsDict["timezone"] as? String ?? ""
            baseline.createdAt = Date()
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: signalsDict) {
                baseline.signalsJSON = jsonData
            }
            
            try realm.write {
                realm.add(baseline, update: .modified)
            }
            print("  ✅ Baseline saved to Realm")
        } catch {
            print("  ❌ Failed to save baseline: \(error)")
        }
    }
    
    // MARK: - USER MANAGEMENT
    private func getExistingUser(email: String) -> UserModel? {
        do {
            let realm = try Realm()
            return realm.objects(UserModel.self).filter("email == %@", email).first
        } catch {
            print("❌ Error accessing Realm: \(error)")
            return nil
        }
    }
    private func updateExistingUser(_ user: UserModel, with userId: String, name: String, method: String) {
        do {
            let realm = try Realm()
            
            if user.userId != userId {
                print("⚠️ UserId changed - creating new record")
                
                // ✅ FIX: Get values BEFORE deleting
                let oldEmail = user.email
                let oldName = user.name
                
                try realm.write {
                    // Delete old user
                    realm.delete(user)
                }
                
                // ✅ FIX: Create new user with fresh object (not referencing deleted one)
                let newUser = UserModel()
                newUser.userId = userId
                newUser.email = oldEmail  // Use saved email
                newUser.name = name
                newUser.method = method
                
                try realm.write {
                    realm.add(newUser)
                }
                
                print("✅ Created new user record with updated userId")
            } else {
                // Same userId - just update
                try realm.write {
                    user.name = name
                    user.method = method
                }
                print("✅ Updated existing user info")
            }
        } catch {
            print("❌ Error updating existing user: \(error)")
        }
    }

    // MARK: - PERSISTENCE
    private func saveUserToRealm(userId: String, name: String, email: String, method: String) {
        let user = UserModel()
        user.userId = userId
        user.email = email
        user.name = name
        user.method = method
        
        do {
            let fileURL = Realm.Configuration.defaultConfiguration.fileURL!
            let folderPath = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folderPath, withIntermediateDirectories: true, attributes: nil)
            
            let realm = try Realm()
            try realm.write {
                realm.add(user, update: .modified)
            }
            print("✅ User saved successfully to Realm")
        } catch {
            print("❌ Failed to save user to Realm: \(error)")
        }
    }
    
    private func saveUserToFirestore(userId: String, name: String, email: String, method: String) {
        let db = Firestore.firestore()
        let doc = db.collection("users").document(userId)
        let data: [String: Any] = [
            "userId": userId,
            "name": name,
            "email": email,
            "signInMethod": method,
            "securitySetupComplete": false,
            "createdAt": FieldValue.serverTimestamp(),
            "lastSignInAt": FieldValue.serverTimestamp()
        ]
        
        doc.setData(data, merge: true) { error in
            if let error = error {
                print("❌ Firestore save error: \(error.localizedDescription)")
            } else {
                print("✅ Saved to Firestore: \(email)")
            }
        }
    }
    
    // MARK: - HELPERS
    private func showAlert(title: String, message: String) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}
