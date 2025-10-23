import UIKit
import RealmSwift
import CoreLocation
import FirebaseAuth

class HomeViewController: UIViewController {
    
    private var sessionStart: Date?
    private var currentVisit: LocationVisit?
    var userId: String = ""
    var firebaseToken: String = ""
    private var currentDeviceStatus: String = "Unknown"
    
    // UI Elements
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var headerView: UIView!
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var statusCardView: UIView!
    private var deviceStatusLabel: UILabel!
    private var networkStatusLabel: UILabel!
    private var demoCardView: UIView!
    private var actionsHeaderLabel: UILabel!
    private var actionsStackView: UIStackView!
    private var actionStreamButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        
        print("Entered HomePage at \(Date())")
        startSession()
        setupUI()
        
        if let user = RealmManager.shared.fetchAllUsers().first {
            userId = user.userId
            print("Found user ID: \(userId)")
        }
        
        if let currentUser = Auth.auth().currentUser {
            currentUser.getIDToken { token, error in
                if let token = token {
                    self.firebaseToken = token
                }
            }
        }
        
        setupNavigationItems()
    }
    
    private func setupNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Sign Out",
            style: .plain,
            target: self,
            action: #selector(handleSignOut)
        )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        updateDeviceStatus()
        updateNetworkStatus()
        
        // Fetch cross-device actions on login
        if !userId.isEmpty {
            Task {
                await ActionLogger.shared.fetchAndStoreActionsFromFirebase(userId: userId)
                print("HOT RELOAD: Fetched cross-device actions")
            }
        }
    }
    
    private func updateNetworkStatus() {
        let isOnline = NetworkStateManager.shared.isConnected
        let connectionType = NetworkStateManager.shared.connectionType
        
        if isOnline {
            networkStatusLabel.text = "Network: Online (\(connectionType))"
            networkStatusLabel.textColor = .systemGreen
        } else {
            networkStatusLabel.text = "Network: Offline"
            networkStatusLabel.textColor = .systemRed
        }
    }
    
    private func updateDeviceStatusWithNetworkInfo() {
        let isOnline = NetworkStateManager.shared.isConnected
        
        if isOnline {
            deviceStatusLabel.text = "Device: \(currentDeviceStatus) (Online)"
            deviceStatusLabel.textColor = currentDeviceStatus == "Primary" ? .systemGreen : .systemOrange
        } else {
            deviceStatusLabel.text = "Device: \(currentDeviceStatus) (Offline)"
            deviceStatusLabel.textColor = .systemRed
        }
    }
    
    private func updateDeviceStatus() {
        Task {
            do {
                guard let user = RealmManager.shared.fetchAllUsers().first else {
                    await MainActor.run {
                        self.currentDeviceStatus = "Unknown"
                        self.updateDeviceStatusWithNetworkInfo()
                    }
                    return
                }
                
                let currentDeviceId = UIDevice.current.deviceIdentifier
                
                // Check if this device is PRIMARY or SECONDARY
                let deviceType = try await DeviceClassifier.shared.classifyDevice(
                    userId: user.userId,
                    currentDeviceId: currentDeviceId
                )
                
                await MainActor.run {
                    switch deviceType {
                    case .primary:
                        self.currentDeviceStatus = "Primary"
                    case .secondary:
                        self.currentDeviceStatus = "Secondary"
                    case .unknown:
                        self.currentDeviceStatus = "Unknown"
                    }
                    self.updateDeviceStatusWithNetworkInfo()
                }
                
            } catch {
                await MainActor.run {
                    self.currentDeviceStatus = "Unknown"
                    self.updateDeviceStatusWithNetworkInfo()
                }
            }
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        setupHeaderView()
        setupStatusCard()
        setupDemoCard()
        setupActionsSection()
        setupActionStreamButton()
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actionStreamButton.topAnchor, constant: -16),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            statusCardView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            statusCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            demoCardView.topAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: 16),
            demoCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            demoCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            actionsHeaderLabel.topAnchor.constraint(equalTo: demoCardView.bottomAnchor, constant: 24),
            actionsHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            actionsStackView.topAnchor.constraint(equalTo: actionsHeaderLabel.bottomAnchor, constant: 12),
            actionsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionsStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupHeaderView() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerView)
        
        titleLabel = UILabel()
        titleLabel.text = "Dashboard"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .left
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        subtitleLabel = UILabel()
        subtitleLabel.text = "Trust-based authentication"
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textAlignment = .left
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }
    
    private func setupStatusCard() {
        statusCardView = UIView()
        statusCardView.backgroundColor = .systemBackground
        statusCardView.layer.cornerRadius = 16
        statusCardView.layer.shadowColor = UIColor.black.cgColor
        statusCardView.layer.shadowOpacity = 0.08
        statusCardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        statusCardView.layer.shadowRadius = 12
        statusCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusCardView)
        
        let statusStackView = UIStackView()
        statusStackView.axis = .vertical
        statusStackView.spacing = 14
        statusStackView.translatesAutoresizingMaskIntoConstraints = false
        statusCardView.addSubview(statusStackView)
        
        let statusHeaderLabel = UILabel()
        statusHeaderLabel.text = "System Status"
        statusHeaderLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        statusHeaderLabel.textColor = .label
        
        deviceStatusLabel = UILabel()
        deviceStatusLabel.text = "Device: Checking..."
        deviceStatusLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        deviceStatusLabel.textColor = .secondaryLabel
        
        networkStatusLabel = UILabel()
        networkStatusLabel.text = "Network: Checking..."
        networkStatusLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        networkStatusLabel.textColor = .secondaryLabel
        
        [statusHeaderLabel, deviceStatusLabel, networkStatusLabel].forEach {
            statusStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            statusStackView.topAnchor.constraint(equalTo: statusCardView.topAnchor, constant: 18),
            statusStackView.leadingAnchor.constraint(equalTo: statusCardView.leadingAnchor, constant: 18),
            statusStackView.trailingAnchor.constraint(equalTo: statusCardView.trailingAnchor, constant: -18),
            statusStackView.bottomAnchor.constraint(equalTo: statusCardView.bottomAnchor, constant: -18)
        ])
    }
    
    private func setupDemoCard() {
        demoCardView = UIView()
        demoCardView.backgroundColor = .systemBlue.withAlphaComponent(0.08)
        demoCardView.layer.cornerRadius = 16
        demoCardView.layer.borderWidth = 1.5
        demoCardView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        demoCardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(demoCardView)
        
        let demoLabel = UILabel()
        demoLabel.text = "Action Streaming Demo"
        demoLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        demoLabel.textColor = .systemBlue
        demoLabel.translatesAutoresizingMaskIntoConstraints = false
        demoCardView.addSubview(demoLabel)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Tap buttons to log actions. View real-time cross-device sync in Action Stream."
        descriptionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        descriptionLabel.textColor = .systemBlue.withAlphaComponent(0.8)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        demoCardView.addSubview(descriptionLabel)
        
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 10
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        demoCardView.addSubview(buttonStackView)
        
        let buttonTitles = ["Button", "Screen", "Input", "Scroll"]
        
        for title in buttonTitles {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(logTestAction(_:)), for: .touchUpInside)
            buttonStackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            demoLabel.topAnchor.constraint(equalTo: demoCardView.topAnchor, constant: 16),
            demoLabel.leadingAnchor.constraint(equalTo: demoCardView.leadingAnchor, constant: 16),
            demoLabel.trailingAnchor.constraint(equalTo: demoCardView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: demoLabel.bottomAnchor, constant: 6),
            descriptionLabel.leadingAnchor.constraint(equalTo: demoCardView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: demoCardView.trailingAnchor, constant: -16),
            
            buttonStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            buttonStackView.leadingAnchor.constraint(equalTo: demoCardView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: demoCardView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: demoCardView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 42)
        ])
    }
    
    @objc private func logTestAction(_ sender: UIButton) {
        guard let actionType = sender.title(for: .normal) else { return }
        
        let payload: [String: Any] = [
            "screen": "Home",
            "timestamp": Date().timeIntervalSince1970,
            "button": actionType,
            "deviceStatus": currentDeviceStatus
        ]
        
        let actionTypeKey = actionType.uppercased().replacingOccurrences(of: " ", with: "_")
        ActionLogger.shared.logAction(type: actionTypeKey, payload: payload)
        
        // Visual feedback
        let originalColor = sender.backgroundColor
        sender.backgroundColor = .systemGreen
        UIView.animate(withDuration: 0.3, delay: 0.15) {
            sender.backgroundColor = originalColor
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Brief toast notification
        Task {
            let stats = await ActionLogger.shared.getQueueStats()
            await MainActor.run {
                self.showToast("Action logged! Queue: \(stats.pending) pending")
            }
        }
    }
    
    private func showToast(_ message: String) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textAlignment = .center
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: actionStreamButton.topAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            toastLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
    
    private func setupActionStreamButton() {
        actionStreamButton = UIButton(type: .system)
        actionStreamButton.setTitle("View Action Stream", for: .normal)
        actionStreamButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        actionStreamButton.backgroundColor = .systemBlue
        actionStreamButton.setTitleColor(.white, for: .normal)
        actionStreamButton.layer.cornerRadius = 14
        actionStreamButton.layer.shadowColor = UIColor.systemBlue.cgColor
        actionStreamButton.layer.shadowOpacity = 0.3
        actionStreamButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        actionStreamButton.layer.shadowRadius = 8
        actionStreamButton.translatesAutoresizingMaskIntoConstraints = false
        actionStreamButton.addTarget(self, action: #selector(showActivityFeed), for: .touchUpInside)
        
        view.addSubview(actionStreamButton)
        
        NSLayoutConstraint.activate([
            actionStreamButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            actionStreamButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionStreamButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionStreamButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }
    
    @objc private func showActivityFeed() {
        let activityVC = ActivityFeedViewController()
        navigationController?.pushViewController(activityVC, animated: true)
    }
    
    private func setupActionsSection() {
        actionsHeaderLabel = UILabel()
        actionsHeaderLabel.text = "Test Actions"
        actionsHeaderLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        actionsHeaderLabel.textColor = .label
        actionsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsHeaderLabel)
        
        actionsStackView = UIStackView()
        actionsStackView.axis = .vertical
        actionsStackView.spacing = 10
        actionsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsStackView)
        
        let actions: [(title: String, subtitle: String, action: Selector)] = [
            ("Profile Manager", "Edit profile and view history", #selector(openProfileEdit)),
            ("Trust Snapshot", "Save trust snapshot", #selector(testTrustSnapshot)),
            ("Device Status", "Check device classification", #selector(checkDeviceStatus))
        ]
        
        for (title, subtitle, action) in actions {
            let actionView = createActionView(title: title, subtitle: subtitle, action: action)
            actionsStackView.addArrangedSubview(actionView)
        }
    }
    
    private func createActionView(title: String, subtitle: String, action: Selector) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.06
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 6
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        containerView.addSubview(button)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 3
        stackView.alignment = .leading
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        
        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chevronImageView)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 70),
            
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 10),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        return containerView
    }
    
    // MARK: - Profile Manager
    
    @objc private func openProfileEdit() {
        let profileVC = ProfileEditViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    // MARK: - Test Methods
    
    @objc private func testTrustSnapshot() {
        guard !userId.isEmpty, let user = RealmManager.shared.fetchAllUsers().first else {
            showAlert("Error", "No user data available")
            return
        }
        
        TrustSnapshotManager.shared.saveTrustSnapshot(for: userId, email: user.email)
        
        showAlert(
            "Trust Snapshot",
            """
            Trust snapshot saved successfully.
            
            Jailbreak: \(DeviceSecurityChecker.isJailbroken())
            VPN: \(VPNChecker.shared.isVPNConnected())
            Timezone: \(TimeZone.current.identifier)
            """
        )
    }
    
    @objc private func checkDeviceStatus() {
        guard !userId.isEmpty else {
            showAlert("Error", "No user data available")
            return
        }
        
        Task {
            do {
                let currentDeviceId = UIDevice.current.deviceIdentifier
                let deviceType = try await DeviceClassifier.shared.classifyDevice(
                    userId: userId,
                    currentDeviceId: currentDeviceId
                )
                
                let statusText: String
                switch deviceType {
                case .primary:
                    statusText = "PRIMARY Device"
                case .secondary:
                    statusText = "SECONDARY Device"
                case .unknown:
                    statusText = "Unknown Device Type"
                }
                
                await MainActor.run {
                    self.showAlert(
                        "Device Status",
                        """
                        \(statusText)
                        
                        Device ID: \(String(currentDeviceId.prefix(12)))...
                        User ID: \(String(userId.prefix(12)))...
                        """
                    )
                }
                
            } catch {
                await MainActor.run {
                    self.showAlert("Error", "Failed to check device status: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func startSession() {
        sessionStart = Date()
        
        guard let userId = RealmManager.shared.fetchAllUsers().first?.userId else { return }
        
        do {
            let realm = try Realm()
            let visit = LocationVisit()
            visit.userId = userId
            visit.latitude = 37.33233141
            visit.longitude = -122.0312186
            visit.visitCount = 0
            visit.totalDurationMinutes = 0
            
            try realm.write {
                realm.add(visit)
            }
            currentVisit = visit
        } catch {
            print("Error saving visit: \(error)")
        }
    }
    
    @objc private func handleSignOut() {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            let loginVC = LoginViewController()
            let navController = UINavigationController(rootViewController: loginVC)
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        }
    }
    
    private func showAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
