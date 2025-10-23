import UIKit
import RealmSwift

class ActivityFeedViewController: UIViewController {
    
    private let tableView = UITableView()
    private var actions: [UserActionQueue] = []
    private var pollingTimer: Timer?
    private var userId: String = ""
    
    private let statsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Action Stream"
        view.backgroundColor = .systemBackground
        
        // Add refresh button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(manualSync)
        )
        
        setupUI()
        loadUserId()
        
        Task {
            await loadLocalActions()
            startPolling()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollingTimer?.invalidate()
    }
    
    private func setupUI() {
        // Stats label
        view.addSubview(statsLabel)
        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        // Table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ActionCell.self, forCellReuseIdentifier: "ActionCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func loadUserId() {
        if let realm = RealmManager.shared.getRealmInstance(),
           let user = realm.objects(UserModel.self).first {
            userId = user.userId
        }
    }
    
    private func loadLocalActions() async {
        actions = await ActionLogger.shared.getRecentActions(limit: 50)
        await updateStats()
        
        await MainActor.run {
            tableView.reloadData()
        }
    }
    
    private func updateStats() async {
        let stats = await ActionLogger.shared.getQueueStats()
        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let deviceActions = actions.filter { $0.deviceId == currentDeviceId }.count
        let otherDeviceActions = actions.filter { $0.deviceId != currentDeviceId }.count
        
        await MainActor.run {
            statsLabel.text = """
            Queue: \(stats.pending) pending | \(stats.synced) synced | \(stats.failed) failed
            Actions: \(deviceActions) this device | \(otherDeviceActions) other devices
            Total: \(actions.count) actions
            """
        }
    }
    
    private func startPolling() {
        guard !userId.isEmpty else { return }
        
        // Poll Firebase every 3 seconds for new actions
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchFirebaseActions()
        }
        
        // Fetch immediately
        fetchFirebaseActions()
    }
    
    private func fetchFirebaseActions() {
        Task {
            do {
                // Fetch from Firebase and store locally
                await ActionLogger.shared.fetchAndStoreActionsFromFirebase(userId: userId)
                
                await MainActor.run {
                    Task {
                        // Reload local actions (now includes cross-device)
                        await loadLocalActions()
                        print("📊 ACTIVITY FEED: Synced cross-device actions")
                    }
                }
                
            } catch {
                print("❌ ACTIVITY FEED: Failed to fetch - \(error)")
            }
        }
    }
    
    @objc private func manualSync() {
        Task {
            await ActionLogger.shared.fetchAndStoreActionsFromFirebase(userId: userId)
            await loadLocalActions()
            
            // Show brief confirmation
            await MainActor.run {
                let alert = UIAlertController(title: "Synced", message: "Cross-device actions updated", preferredStyle: .alert)
                present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true)
                }
            }
        }
    }
    
    @objc private func refreshData() {
        Task {
            await loadLocalActions()
            fetchFirebaseActions()
            
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.tableView.refreshControl?.endRefreshing()
                }
            }
        }
    }
}

// MARK: - TableView Delegate & DataSource

extension ActivityFeedViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! ActionCell
        let action = actions[indexPath.row]
        cell.configure(with: action)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Custom Cell

class ActionCell: UITableViewCell {
    
    private let actionTypeLabel = UILabel()
    private let deviceLabel = UILabel()
    private let timestampLabel = UILabel()
    private let statusLabel = UILabel()
    private let payloadLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        actionTypeLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        deviceLabel.font = .systemFont(ofSize: 12)
        deviceLabel.textColor = .systemGray
        timestampLabel.font = .systemFont(ofSize: 12)
        timestampLabel.textColor = .systemGray
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        payloadLabel.font = .systemFont(ofSize: 11)
        payloadLabel.textColor = .systemGray2
        payloadLabel.numberOfLines = 1
        
        let stackView = UIStackView(arrangedSubviews: [
            actionTypeLabel,
            deviceLabel,
            payloadLabel,
            timestampLabel,
            statusLabel
        ])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with action: UserActionQueue) {
        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let isThisDevice = action.deviceId == currentDeviceId
        
        actionTypeLabel.text = action.actionType
        
        // Show device origin clearly with icons
        if isThisDevice {
            deviceLabel.text = "📱 This Device"
            deviceLabel.textColor = .systemGreen
        } else {
            deviceLabel.text = "🔄 Device: \(String(action.deviceId.prefix(8)))..."
            deviceLabel.textColor = .systemBlue
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm:ss a"
        timestampLabel.text = formatter.string(from: action.createdAt)
        
        switch action.syncStatus {
        case "SYNCED":
            statusLabel.text = isThisDevice ? "✅ Synced" : "✅ From Cloud"
            statusLabel.textColor = .systemGreen
        case "PENDING":
            statusLabel.text = "⏳ Pending"
            statusLabel.textColor = .systemOrange
        case "FAILED":
            statusLabel.text = "❌ Failed"
            statusLabel.textColor = .systemRed
        default:
            statusLabel.text = action.syncStatus
            statusLabel.textColor = .systemGray
        }
        
        // Fixed: getPayloadDict() returns non-optional dictionary
        let payload = action.getPayloadDict()
        if !payload.isEmpty {
            payloadLabel.text = "Payload: \(payload.keys.joined(separator: ", "))"
        } else {
            payloadLabel.text = "No payload"
        }
    }
}
