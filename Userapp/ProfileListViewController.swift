//
//  ProfileListViewController.swift
//  Userapp
//

import UIKit
import RealmSwift
import FirebaseFirestore

class ProfileListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var userId: String = ""
    private var profiles: [UserProfile] = []
    private var tableView: UITableView!
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Edit History"
        view.backgroundColor = .systemGroupedBackground
        
        setupUI()
        loadProfiles()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh profiles every time the screen appears
        loadProfiles()
    }
    private func setupUI() {
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProfileHistoryCell.self, forCellReuseIdentifier: "ProfileCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    private func loadProfiles() {
        profiles = RealmManager.shared.fetchAllProfiles(for: userId)
        tableView.reloadData()
        
        print("🔍 FIRESTORE: Fetching profiles for userId: \(userId)")
        
        // SIMPLIFIED QUERY - no index needed
        db.collection("user_profiles")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ FIRESTORE: Failed to fetch - \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ FIRESTORE: No documents found")
                    return
                }
                
                print("✅ FIRESTORE: Found \(documents.count) documents")
                
                guard let realm = RealmManager.shared.getRealmInstance() else { return }
                
                // Sort in memory instead of in the query
                let sortedDocs = documents.sorted {
                    ($0.data()["version"] as? Int ?? 0) > ($1.data()["version"] as? Int ?? 0)
                }
                
                var newProfilesAdded = false
                
                for doc in sortedDocs {
                    let data = doc.data()
                    guard let name = data["name"] as? String,
                          let email = data["email"] as? String,
                          let phone = data["phoneNumber"] as? String,
                          let version = data["version"] as? Int else {
                        continue
                    }
                    
                    let exists = realm.objects(UserProfile.self)
                        .filter("userId == %@ AND version == %@", self.userId, version)
                        .first
                    
                    if exists == nil {
                        let profile = UserProfile(userId: self.userId, name: name, email: email, phoneNumber: phone)
                        profile.version = version
                        
                        if let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() {
                            profile.createdAt = createdAt
                        }
                        if let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() {
                            profile.updatedAt = updatedAt
                        }
                        
                        try? realm.write {
                            realm.add(profile)
                        }
                        
                        newProfilesAdded = true
                        print("✅ Added profile version \(version) from Firestore")
                    }
                }
                
                if newProfilesAdded {
                    DispatchQueue.main.async {
                        self.profiles = RealmManager.shared.fetchAllProfiles(for: self.userId)
                        self.tableView.reloadData()
                        print("✅ Profile list updated with Firestore data")
                    }
                }
            }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath) as! ProfileHistoryCell
        cell.configure(with: profiles[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let profile = profiles[indexPath.row]
        showProfileDetail(profile)
    }
    
    private func showProfileDetail(_ profile: UserProfile) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let message = """
        Name: \(profile.name)
        Email: \(profile.email)
        Phone: \(profile.phoneNumber)
        
        Version: \(profile.version)
        Updated: \(formatter.string(from: profile.updatedAt))
        """
        
        let alert = UIAlertController(title: "Profile Details", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restore", style: .default) { [weak self] _ in
            self?.restoreProfile(profile)
        })
        present(alert, animated: true)
    }
    
    private func restoreProfile(_ profile: UserProfile) {
        guard let realm = RealmManager.shared.getRealmInstance() else { return }
        
        do {
            let newProfile = UserProfile(userId: profile.userId, name: profile.name, email: profile.email, phoneNumber: profile.phoneNumber)
            newProfile.version = (profiles.first?.version ?? 0) + 1
            newProfile.profileImagePath = profile.profileImagePath
            
            try realm.write {
                realm.add(newProfile)
            }
            
            let payload: [String: Any] = [
                "action": "PROFILE_RESTORED",
                "restored_version": profile.version,
                "new_version": newProfile.version,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            ActionLogger.shared.logAction(type: "PROFILE_RESTORED", payload: payload)
            
            loadProfiles()
            
            let alert = UIAlertController(title: "Restored", message: "Profile restored as version \(newProfile.version)", preferredStyle: .alert)
            present(alert, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                alert.dismiss(animated: true)
            }
            
        } catch {
            let alert = UIAlertController(title: "Error", message: "Failed to restore profile", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}


class ProfileHistoryCell: UITableViewCell {
    
    private let versionLabel = UILabel()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        versionLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        versionLabel.textColor = .systemBlue
        
        nameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel
        
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .tertiaryLabel
        
        let stackView = UIStackView(arrangedSubviews: [versionLabel, nameLabel, emailLabel, dateLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with profile: UserProfile) {
        versionLabel.text = "Version \(profile.version)"
        nameLabel.text = profile.name
        emailLabel.text = profile.email
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        dateLabel.text = "Updated: \(formatter.string(from: profile.updatedAt))"
    }
}
