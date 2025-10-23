//
//  DecayTestViewController.swift
//  Userapp
//
//  Created by Ri on 10/15/25.
//


import UIKit
import FirebaseAuth
import RealmSwift

class DecayTestViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTestButtons()
    }
    
    private func setupTestButtons() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 300)
        ])
        
        // Test buttons
        addTestButton(to: stackView, title: "🧪 Test: 30 Min Inactive", hours: 0.5)
        addTestButton(to: stackView, title: "🧪 Test: 1 Hour Inactive", hours: 1)
        addTestButton(to: stackView, title: "⚠️ Test: 1.5 Hours (Warning)", hours: 1.5)
        addTestButton(to: stackView, title: "🚫 Test: 2 Hours (Removal)", hours: 2)
        
        // Reset button
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("🔄 Reset Baseline", for: .normal)
        resetButton.addTarget(self, action: #selector(resetBaseline), for: .touchUpInside)
        stackView.addArrangedSubview(resetButton)
    }
    
    private func addTestButton(to stackView: UIStackView, title: String, hours: Double) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(testDecay(_:)), for: .touchUpInside)
        button.tag = Int(hours * 100) // Store hours as tag
        stackView.addArrangedSubview(button)
    }
    
    @objc private func testDecay(_ sender: UIButton) {
        let hours = Double(sender.tag) / 100.0
        
        Task {
            await simulateInactivity(hours: hours)
            
            // Wait a moment then re-verify
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await reVerifyUser()
        }
    }
    
    @objc private func resetBaseline() {
        Task {
            await Task { @MainActor in
                do {
                    let realm = try Realm()
                    let userId = Auth.auth().currentUser?.uid ?? ""
                    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                    
                    if let baseline = realm.objects(SecondaryDeviceBaseline.self)
                        .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                        .first {
                        try realm.write {
                            baseline.lastLoginDate = Date()
                            baseline.consecutiveActiveDays = 0
                            baseline.lastTrustScore = 100
                            baseline.inactiveDayCounter = 0
                        }
                        
                        let alert = UIAlertController(
                            title: "✅ Reset Complete",
                            message: "Baseline reset to current time",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                        
                        print("🔄 Baseline reset to now")
                    }
                } catch {
                    print("❌ Error: \(error)")
                }
            }.value
        }
    }
    
    private func simulateInactivity(hours: Double) async {
        await Task { @MainActor in
            do {
                let realm = try Realm()
                let userId = Auth.auth().currentUser?.uid ?? ""
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
                
                // Update SECONDARY baseline
                if let baseline = realm.objects(SecondaryDeviceBaseline.self)
                    .filter("userId == %@ AND deviceId == %@", userId, deviceId)
                    .first {
                    
                    let secondsAgo = hours * 3600
                    
                    try realm.write {
                        baseline.lastLoginDate = Date().addingTimeInterval(-secondsAgo)
                    }
                    
                    print("🧪 TEST: Simulated \(hours) hours of inactivity")
                    print("   Last login set to: \(baseline.lastLoginDate)")
                    print("   Current time: \(Date())")
                    print("   Difference: \(secondsAgo / 3600) hours")
                }
                
            } catch {
                print("❌ Error: \(error)")
            }
        }.value
    }
    
    private func reVerifyUser() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let email = Auth.auth().currentUser?.email else {
            print("❌ No user logged in")
            return
        }
        
        print("\n🔄 RE-VERIFYING USER AFTER SIMULATED INACTIVITY...")
        print("=" + String(repeating: "=", count: 60))
        
        TrustVerifier.shared.verifyUser(userId: userId, email: email) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .trusted(let userId):
                    print("✅ RESULT: User still TRUSTED")
                    print("=" + String(repeating: "=", count: 60))
                    
                    let alert = UIAlertController(
                        title: "✅ Still Trusted",
                        message: "User: \(userId)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    
                case .requiresSecurityVerification(let userId, let reason):
                    print("⚠️ RESULT: Security verification REQUIRED")
                    print("   Reason: \(reason)")
                    print("=" + String(repeating: "=", count: 60))
                    
                    let alert = UIAlertController(
                        title: "⚠️ Verification Required",
                        message: reason,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                    
                case .blocked(let reason):
                    print("🚫 RESULT: User BLOCKED")
                    print("   Reason: \(reason)")
                    print("=" + String(repeating: "=", count: 60))
                    
                    let alert = UIAlertController(
                        title: "🚫 Device Blocked",
                        message: reason,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        // Sign out and return to login
                        try? Auth.auth().signOut()
                        self?.navigationController?.popToRootViewController(animated: true)
                    })
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}
