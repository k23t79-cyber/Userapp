//
// SceneDelegate.swift
// Userapp
//

import UIKit
import RealmSwift
import Firebase
import FirebaseAuth
import FirebaseFirestore

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // ✅ Base URL constant
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("=== SCENE DELEGATE: Scene Connecting ===")
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        showLoadingScreen()
        checkAuthenticationState()
        
        print("=== SCENE DELEGATE: Window Made Visible ===")
    }
    
    private func showLoadingScreen() {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = loadingVC.view.center
        activityIndicator.startAnimating()
        loadingVC.view.addSubview(activityIndicator)
        
        window?.rootViewController = loadingVC
        window?.makeKeyAndVisible()
    }
    
    private func checkAuthenticationState() {
        do {
            let realm = try Realm()
            let users = realm.objects(UserModel.self)
            
            print("DEBUG: Realm contains \(users.count) user(s)")
            for (index, user) in users.enumerated() {
                print(" User \(index + 1):")
                print("  - Email: \(user.email)")
                print("  - UserId: \(user.userId)")
                print("  - Method: \(user.method)")
                print("  - Name: \(user.name)")
            }
            
            if let realmUser = users.first {
                print("Checking authentication state...")
                print("SUCCESS: Found user in Realm: \(realmUser.email)")
                waitForFirebaseAuth(expectedUserId: realmUser.userId, email: realmUser.email)
            } else {
                print("NO USER FOUND: Showing login screen")
                navigateToLogin()
            }
        } catch {
            print("ERROR: Failed to access Realm: \(error.localizedDescription)")
            navigateToLogin()
        }
    }
    
    private func waitForFirebaseAuth(expectedUserId: String, email: String) {
        print("⏳ Waiting for Firebase Auth to complete...")
        
        var timeoutFired = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            timeoutFired = true
            if self?.authStateListener != nil {
                print("⚠️ TIMEOUT: Firebase Auth took too long")
                self?.handleAuthTimeout(email: email)
            }
        }
        
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self, !timeoutFired else { return }
            
            if let listener = self.authStateListener {
                Auth.auth().removeStateDidChangeListener(listener)
                self.authStateListener = nil
            }
            
            if let firebaseUser = user {
                print("✅ FIREBASE AUTH: User signed in")
                print("   - Firebase UserId: \(firebaseUser.uid)")
                print("   - Firebase Email: \(firebaseUser.email ?? "unknown")")
                print("   - Expected UserId: \(expectedUserId)")
                
                if firebaseUser.uid == expectedUserId {
                    print("✅ USER MATCH: Firebase and Realm users match")
                    self.proceedWithTrustVerification(userId: firebaseUser.uid, email: email)
                } else {
                    print("⚠️ USER MISMATCH")
                    self.handleUserMismatch(realmUserId: expectedUserId, email: email)
                }
            } else {
                print("❌ FIREBASE AUTH: No user signed in")
                self.handleNoFirebaseUser(email: email)
            }
        }
    }
    
    private func handleAuthTimeout(email: String) {
        let alert = UIAlertController(
            title: "Connection Issue",
            message: "Unable to verify your session. Please sign in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            self?.navigateToLogin()
        })
        presentAlert(alert)
    }
    
    private func handleUserMismatch(realmUserId: String, email: String) {
        print("⚠️ Signing out mismatched Firebase user...")
        do {
            try Auth.auth().signOut()
            print("✅ Signed out successfully")
            handleNoFirebaseUser(email: email)
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
            navigateToLogin()
        }
    }
    
    private func handleNoFirebaseUser(email: String) {
        let alert = UIAlertController(
            title: "Session Expired",
            message: "Your session has expired. Please sign in again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            self?.navigateToLogin()
        })
        presentAlert(alert)
    }
    
    // MARK: - Trust Verification
    
    private func ensureUserDocumentExists(userId: String, email: String, completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(userId)
        
        print("🔍 Checking if user document exists in Firestore...")
        
        userDoc.getDocument { snapshot, error in
            if let error = error {
                print("❌ Error checking user document: \(error)")
                completion()
                return
            }
            
            if snapshot?.exists == true {
                print("✅ User document already exists in Firestore")
                
                if let data = snapshot?.data(),
                   let securityComplete = data["security_setup_complete"] as? Bool {
                    print("   - security_setup_complete: \(securityComplete)")
                } else {
                    print("⚠️ security_setup_complete field missing, updating...")
                    userDoc.updateData(["security_setup_complete": false]) { error in
                        if let error = error {
                            print("❌ Failed to update field: \(error)")
                        }
                    }
                }
                completion()
            } else {
                print("🆕 Creating new user document in Firestore...")
                
                let userData: [String: Any] = [
                    "userId": userId,
                    "email": email,
                    "created_at": FieldValue.serverTimestamp(),
                    "security_setup_complete": false,
                    "trust_level": "new_user",
                    "last_login": FieldValue.serverTimestamp()
                ]
                
                userDoc.setData(userData) { error in
                    if let error = error {
                        print("❌ Failed to create user document: \(error)")
                    } else {
                        print("✅ User document created successfully")
                    }
                    completion()
                }
            }
        }
    }
    
    private func proceedWithTrustVerification(userId: String, email: String) {
        print("ACTION: Starting trust verification...")
        print("   - UserId: \(userId)")
        print("   - Email: \(email)")
        
        ensureUserDocumentExists(userId: userId, email: email) { [weak self] in
            guard let self = self else { return }
            
            TrustVerifier.shared.verifyUser(userId: userId, email: email) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .requiresSecurityVerification(let userId, let reason):
                    print("⚠️ Security verification required: \(reason)")
                    self.handleSecurityVerification(userId: userId, email: email, reason: reason)
                    
                case .trusted(let userId):
                    print("✅ User trusted - navigating to Home")
                    self.navigateToHome()
                    
                case .blocked(let reason):
                    print("🚫 User blocked: \(reason)")
                    self.handleBlockedUser(reason: reason)
                }
            }
        }
    }
    
    // MARK: - Security Verification Flow
    
    func handleSecurityVerification(userId: String, email: String, reason: String) {
        print("🔐 SECURITY VERIFICATION: \(reason)")
        
        switch reason {
        case "security_setup":
            print("📝 NEW USER: Showing security question setup")
            showSecurityQuestionSetup(userId: userId, email: email)
            
        case "security_verification":
            print("🔐 EXISTING USER: Showing single question verification")
            showSingleQuestionVerification(userId: userId, email: email)
            
        default:
            print("⚠️ OTHER: \(reason)")
            showFullSecurityVerification(userId: userId, email: email)
        }
    }
    
    private func showSecurityQuestionSetup(userId: String, email: String) {
        // ✅ CORRECT: GET /security/template-questions
        let questionsAPIURL = "\(baseURL)/security/template-questions"
        
        guard let url = URL(string: questionsAPIURL) else {
            print("❌ Invalid URL")
            showErrorAlert(message: "Invalid API URL")
            return
        }
        
        print("🔍 [SETUP] Fetching template questions from: \(questionsAPIURL)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ API Error:", error.localizedDescription)
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to load security questions.")
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    DispatchQueue.main.async {
                        self?.showErrorAlert(message: "Server error (\(httpResponse.statusCode))")
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            do {
                let questions = try JSONDecoder().decode([SecurityQuestion].self, from: data)
                print("✅ Successfully decoded \(questions.count) template questions")
                
                DispatchQueue.main.async {
                    let setupVC = SecurityQuestionSetupViewController()
                    setupVC.questions = questions
                    setupVC.userId = userId
                    setupVC.firebaseToken = ""
                    
                    let nav = UINavigationController(rootViewController: setupVC)
                    nav.modalPresentationStyle = .fullScreen
                    self?.window?.rootViewController = nav
                    self?.window?.makeKeyAndVisible()
                }
            } catch {
                print("❌ Decoding Error:", error)
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to parse questions.")
                }
            }
        }.resume()
    }
    
    private func showSingleQuestionVerification(userId: String, email: String) {
        // ✅ CORRECT: GET /security/user-question/:id
        let verifyAPIURL = "\(baseURL)/security/user-question/\(userId)"
        
        guard let url = URL(string: verifyAPIURL) else {
            print("❌ Invalid verification URL")
            showErrorAlert(message: "Invalid API URL")
            return
        }
        
        print("🔍 [VERIFY] Fetching user's security question from: \(verifyAPIURL)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ API Error:", error.localizedDescription)
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to load security question.")
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status Code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    print("⚠️ User has no security questions (404) - showing setup")
                    DispatchQueue.main.async {
                        self?.showSecurityQuestionSetup(userId: userId, email: email)
                    }
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ Server returned error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        self?.showErrorAlert(message: "Server error. Please try again.")
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("📦 Raw Response: \(rawString.prefix(200))...")
            }
            
            do {
                // Backend returns a single UserSecurityQuestion object
                let userQuestion = try JSONDecoder().decode(UserSecurityQuestion.self, from: data)
                
                print("✅ Successfully decoded user's security question")
                
                DispatchQueue.main.async {
                    let verifyVC = SingleSecurityQuestionViewController()
                    verifyVC.userId = userId
                    verifyVC.firebaseToken = ""
                    verifyVC.questionData = SecurityQuestionData(
                        questionText: userQuestion.question,
                        hint: userQuestion.hint,
                        userId: userId
                    )
                    
                    let nav = UINavigationController(rootViewController: verifyVC)
                    nav.modalPresentationStyle = .fullScreen
                    self?.window?.rootViewController = nav
                    self?.window?.makeKeyAndVisible()
                }
            } catch {
                print("❌ Decoding Error:", error)
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to parse security question.")
                }
            }
        }.resume()
    }
    
    private func showFullSecurityVerification(userId: String, email: String) {
        print("🔐 [FULL VERIFY] Showing SecurityVerificationViewController")
        
        DispatchQueue.main.async { [weak self] in
            let verifyVC = SecurityVerificationViewController()
            verifyVC.userId = userId
            verifyVC.firebaseToken = ""
            
            let nav = UINavigationController(rootViewController: verifyVC)
            nav.modalPresentationStyle = .fullScreen
            self?.window?.rootViewController = nav
            self?.window?.makeKeyAndVisible()
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleBlockedUser(reason: String) {
        let alert = UIAlertController(
            title: "🚫 Device Blocked",
            message: reason,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            do {
                try Auth.auth().signOut()
                print("✅ User signed out after blocking")
            } catch {
                print("❌ Error signing out: \(error)")
            }
            self?.navigateToLogin()
        })
        
        presentAlert(alert)
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToLogin() {
        DispatchQueue.main.async { [weak self] in
            let loginVC = LoginViewController()
            let navController = UINavigationController(rootViewController: loginVC)
            navController.modalPresentationStyle = .fullScreen
            self?.window?.rootViewController = navController
            self?.window?.makeKeyAndVisible()
        }
    }
    
    private func navigateToHome() {
        DispatchQueue.main.async { [weak self] in
            let homeVC = HomeViewController()
            let navController = UINavigationController(rootViewController: homeVC)
            navController.modalPresentationStyle = .fullScreen
            self?.window?.rootViewController = navController
            self?.window?.makeKeyAndVisible()
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Verification Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            self?.checkAuthenticationState()
        })
        
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            self?.navigateToLogin()
        })
        
        presentAlert(alert)
    }
    
    private func presentAlert(_ alert: UIAlertController) {
        DispatchQueue.main.async { [weak self] in
            if let rootVC = self?.window?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Scene Lifecycle
    
    func sceneDidDisconnect(_ scene: UIScene) {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
            authStateListener = nil
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}

// MARK: - Supporting Models

struct UserSecurityQuestion: Codable {
    let user_id: String
    let question_id: String
    let question_text: String
    let hint: String
    
    // Computed properties for easier access
    var id: String { question_id }
    var question: String { question_text }
}


