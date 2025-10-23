import UIKit
import RealmSwift
import CoreLocation

class HomeQuestionViewController: UIViewController {
    
    // MARK: - Properties
    private var sessionStart: Date?
    private var currentVisit: LocationVisit?
    private var trustCheckTimer: Timer?
    
    // MARK: - UI Elements (Programmatic - No IBOutlets)
    private let welcomeLabel: UILabel = {
        let label = UILabel()
        label.text = "🏠 Welcome Home!"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "✅ Trust Status: Verified"
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = .systemGreen
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let sessionInfoLabel: UILabel = {
        let label = UILabel()
        label.text = "Session started..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let trustScoreLabel: UILabel = {
        let label = UILabel()
        label.text = "Trust Score: Checking..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupUI()
        startSession()
        startTrustMonitoring() // ✅ Start monitoring trust
        updateSessionInfo()
        
        print("🏠 Entered HomePage at \(Date())")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Sign Out",
            style: .plain,
            target: self,
            action: #selector(handleSignOut)
        )
        
        // Set navigation title
        self.title = "Home"
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTrustMonitoring()
    }
    
    // MARK: - UI Setup (Programmatic)
    private func setupUI() {
        view.addSubview(welcomeLabel)
        view.addSubview(statusLabel)
        view.addSubview(sessionInfoLabel)
        view.addSubview(trustScoreLabel)
        
        NSLayoutConstraint.activate([
            // Welcome Label
            welcomeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            welcomeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            welcomeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 30),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Trust Score Label
            trustScoreLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            trustScoreLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trustScoreLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Session Info Label
            sessionInfoLabel.topAnchor.constraint(equalTo: trustScoreLabel.bottomAnchor, constant: 40),
            sessionInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sessionInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    private func updateSessionInfo() {
        guard let sessionStart = sessionStart else { return }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        sessionInfoLabel.text = "📱 Session started: \(formatter.string(from: sessionStart))\n🔄 Monitoring trust every 30 seconds..."
    }
    
    // MARK: - Trust Monitoring
    private func startTrustMonitoring() {
        guard let userId = RealmManager.shared.fetchAllUsers().first?.userId else {
            print("⚠️ No userId found for trust monitoring")
            return
        }
        
        print("🔍 Starting trust monitoring for userId: \(userId)")
        statusLabel.text = "🔍 Trust Status: Monitoring..."
        statusLabel.textColor = .systemOrange
        
        // Check trust immediately
        checkTrustStatus(userId: userId)
        
        // Check trust every 30 seconds while app is active
        trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkTrustStatus(userId: userId)
        }
    }
    
    private func stopTrustMonitoring() {
        print("🛑 Stopping trust monitoring")
        trustCheckTimer?.invalidate()
        trustCheckTimer = nil
    }
    
    private func checkTrustStatus(userId: String) {
        print("🔍 Checking trust status...")
        
        TrustSecurityManager.shared.shouldTriggerSecurityVerification(for: userId) { [weak self] shouldVerify, reason in
            DispatchQueue.main.async {
                if shouldVerify {
                    print("🚨 Trust issue detected during session: \(reason)")
                    self?.statusLabel.text = "⚠️ Trust Issue: \(reason)"
                    self?.statusLabel.textColor = .systemRed
                    self?.triggerSecurityVerification(userId: userId, reason: reason)
                } else {
                    print("✅ Trust status OK: \(reason)")
                    self?.statusLabel.text = "✅ Trust Status: Verified"
                    self?.statusLabel.textColor = .systemGreen
                }
                
                // Update trust score display
                self?.updateTrustScoreDisplay()
            }
        }
    }
    
    private func updateTrustScoreDisplay() {
        let defaults = UserDefaults.standard
        let trustScore = defaults.double(forKey: "DeviceTrustScore")
        let lastCheck = defaults.object(forKey: "LastTrustCheck") as? Date
        
        if trustScore > 0 {
            let scoreColor: UIColor
            if trustScore >= 80 {
                scoreColor = .systemGreen
            } else if trustScore >= 60 {
                scoreColor = .systemOrange
            } else {
                scoreColor = .systemRed
            }
            
            trustScoreLabel.text = "📊 Trust Score: \(Int(trustScore))/100"
            trustScoreLabel.textColor = scoreColor
        } else {
            trustScoreLabel.text = "📊 Trust Score: Checking..."
            trustScoreLabel.textColor = .systemGray
        }
        
        if let lastCheck = lastCheck {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            sessionInfoLabel.text = "📱 Session active\n🔄 Last trust check: \(formatter.string(from: lastCheck))"
        }
    }
    
    private func triggerSecurityVerification(userId: String, reason: String) {
        stopTrustMonitoring() // Stop monitoring while verifying
        
        print("🚨 Triggering security verification: \(reason)")
        
        // ✅ Use VERIFY Layout for mid-session verification
        let verifyVC = SecurityQuestionVerifyViewController()
        verifyVC.userId = userId
        verifyVC.reason = reason
        
        let nav = UINavigationController(rootViewController: verifyVC)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
    
    // MARK: - Start Session (Location tracking)
    private func startSession() {
        sessionStart = Date()
        
        guard let userId = RealmManager.shared.fetchAllUsers().first?.userId else {
            print("⚠️ No userId found for session tracking")
            return
        }
        
        let lat = 37.33233141   // mock Apple HQ
        let lon = -122.0312186
        
        do {
            let realm = try Realm()
            
            // ✅ Check if same location already exists for this user
            if let existingVisit = realm.objects(LocationVisit.self)
                .filter("userId == %@ AND latitude == %@ AND longitude == %@", userId, lat, lon)
                .first {
                
                print("🔄 Resuming cumulative visit record")
                currentVisit = existingVisit
                
            } else {
                // ✅ Create new location visit record
                let visit = LocationVisit()
                visit.userId = userId
                visit.latitude = lat
                visit.longitude = lon
                visit.visitCount = 0
                visit.totalDurationMinutes = 0
                
                try realm.write {
                    realm.add(visit)
                }
                currentVisit = visit
                print("📍 New location visit record created")
            }
        } catch {
            print("❌ Error saving visit: \(error)")
        }
    }
    
    private func endSession() {
        guard let visit = currentVisit else { return }

        do {
            let realm = try Realm()
            try realm.write {
                // ✅ All changes inside write block
                visit.departureDate = Date()
                visit.updateDuration()
                realm.add(visit, update: .modified)
            }

            print("🕒 Session Duration: \(visit.totalDurationMinutes) minutes (Visits: \(visit.visitCount))")

            // ✅ clustering rule
            if visit.visitCount >= 3 && visit.durationMinutes >= 45 {
                let location = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
                LocationClusterManager.shared.saveOrUpdateCluster(for: location, userId: visit.userId)
                print("📌 Added to cluster (visitCount: \(visit.visitCount), duration: \(visit.durationMinutes) min)")
            } else {
                print("⏳ Not eligible for cluster yet (visitCount: \(visit.visitCount), totalDuration: \(visit.totalDurationMinutes) min)")
            }

        } catch {
            print("❌ Error updating visit: \(error)")
        }
    }
    
    // MARK: - Sign Out
    @objc private func handleSignOut() {
        endSession()
        stopTrustMonitoring() // ✅ Stop trust monitoring on sign out
        print("🚪 User tapped Sign Out")
        
        // Clear stored device ID to simulate device change on next login (for testing)
        // UserDefaults.standard.removeObject(forKey: "LastDeviceID")
        
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            let loginVC = LoginViewController()
            let navController = UINavigationController(rootViewController: loginVC)
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
