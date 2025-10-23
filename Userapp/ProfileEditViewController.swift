//
//  ProfileEditViewController.swift
//  Userapp
//

import UIKit
import RealmSwift
import FirebaseFirestore

class ProfileEditViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private var profileImageView: UIImageView!
    private var nameTextField: UITextField!
    private var emailTextField: UITextField!
    private var phoneTextField: UITextField!
    private var submitButton: UIButton!
    private var viewHistoryButton: UIButton!
    
    private var actualNameField: UITextField?
    private var actualEmailField: UITextField?
    private var actualPhoneField: UITextField?
    
    private var existingProfile: UserProfile?
    private var userId: String = ""
    private var selectedImage: UIImage?
    private let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("ProfileEditViewController viewDidLoad called")
        
        title = "Profile"
        view.backgroundColor = .systemGroupedBackground
        
        if let user = RealmManager.shared.fetchAllUsers().first {
            userId = user.userId
        }
        
        setupUI()
        loadExistingProfile()
    }
    
    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageContainer)
        
        profileImageView = UIImageView()
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = .systemGray3
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 60
        profileImageView.backgroundColor = .systemGray6
        profileImageView.layer.borderWidth = 3
        profileImageView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.isUserInteractionEnabled = true
        imageContainer.addSubview(profileImageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(selectPhoto))
        profileImageView.addGestureRecognizer(tapGesture)
        
        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraIcon.tintColor = .white
        cameraIcon.backgroundColor = .systemBlue
        cameraIcon.layer.cornerRadius = 18
        cameraIcon.clipsToBounds = true
        cameraIcon.contentMode = .center
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(cameraIcon)
        
        let nameContainer = createTextField(placeholder: "Full Name", icon: "person.fill", fieldReference: &actualNameField)
        let emailContainer = createTextField(placeholder: "Email", icon: "envelope.fill", fieldReference: &actualEmailField)
        let phoneContainer = createTextField(placeholder: "Phone Number", icon: "phone.fill", fieldReference: &actualPhoneField)
        
        actualEmailField?.keyboardType = .emailAddress
        actualEmailField?.autocapitalizationType = .none
        actualPhoneField?.keyboardType = .phonePad
        
        let stackView = UIStackView(arrangedSubviews: [nameContainer, emailContainer, phoneContainer])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        submitButton = UIButton(type: .system)
        submitButton.setTitle("Save Profile", for: .normal)
        submitButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        submitButton.backgroundColor = .systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 14
        submitButton.layer.shadowColor = UIColor.systemBlue.cgColor
        submitButton.layer.shadowOpacity = 0.3
        submitButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        submitButton.layer.shadowRadius = 8
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addTarget(self, action: #selector(saveProfile), for: .touchUpInside)
        contentView.addSubview(submitButton)
        
        viewHistoryButton = UIButton(type: .system)
        viewHistoryButton.setTitle("View Edit History", for: .normal)
        viewHistoryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        viewHistoryButton.setTitleColor(.systemBlue, for: .normal)
        viewHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        viewHistoryButton.addTarget(self, action: #selector(viewProfileHistory), for: .touchUpInside)
        contentView.addSubview(viewHistoryButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            imageContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageContainer.widthAnchor.constraint(equalToConstant: 120),
            imageContainer.heightAnchor.constraint(equalToConstant: 120),
            
            profileImageView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: imageContainer.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 120),
            
            cameraIcon.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: -5),
            cameraIcon.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: -5),
            cameraIcon.widthAnchor.constraint(equalToConstant: 36),
            cameraIcon.heightAnchor.constraint(equalToConstant: 36),
            
            stackView.topAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: 32),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            submitButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 32),
            submitButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            submitButton.heightAnchor.constraint(equalToConstant: 54),
            
            viewHistoryButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 16),
            viewHistoryButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            viewHistoryButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createTextField(placeholder: String, icon: String, fieldReference: inout UITextField?) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.05
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.layer.shadowRadius = 3
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemGray
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = .systemFont(ofSize: 16)
        textField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(textField)
        
        fieldReference = textField
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 52),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func loadExistingProfile() {
        existingProfile = RealmManager.shared.fetchLatestProfile(for: userId)
        
        if let profile = existingProfile {
            actualNameField?.text = profile.name
            actualEmailField?.text = profile.email
            actualPhoneField?.text = profile.phoneNumber
            
            if let imagePath = profile.profileImagePath,
               let image = loadImageFromDocuments(imagePath) {
                profileImageView.image = image
                profileImageView.contentMode = .scaleAspectFill
            }
        }
    }
    
    @objc private func selectPhoto() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            selectedImage = image
            profileImageView.image = image
            profileImageView.contentMode = .scaleAspectFill
        }
        dismiss(animated: true)
    }
    
    @objc private func saveProfile() {
        guard let name = actualNameField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            showAlert("Please enter your name")
            return
        }
        
        guard let email = actualEmailField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            showAlert("Please enter your email")
            return
        }
        
        guard let phone = actualPhoneField?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            showAlert("Please enter your phone number")
            return
        }
        
        guard let realm = RealmManager.shared.getRealmInstance() else { return }
        
        do {
            let profile = UserProfile(userId: userId, name: name, email: email, phoneNumber: phone)
            
            if let existing = existingProfile {
                profile.version = existing.version + 1
            }
            
            if let image = selectedImage {
                let imagePath = saveImageToDocuments(image, userId: userId)
                profile.profileImagePath = imagePath
            } else if let existingPath = existingProfile?.profileImagePath {
                profile.profileImagePath = existingPath
            }
            
            try realm.write {
                realm.add(profile)
            }
            
            syncProfileToFirestore(profile: profile)
            
            let payload: [String: Any] = [
                "action": "PROFILE_EDIT",
                "name": name,
                "email": email,
                "phone": phone,
                "version": profile.version,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            ActionLogger.shared.logAction(type: "PROFILE_EDIT", payload: payload)
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            showSuccessAlert("Profile saved successfully! Version \(profile.version)")
            
            existingProfile = profile
            
        } catch {
            showAlert("Failed to save profile: \(error.localizedDescription)")
        }
    }
    
    private func syncProfileToFirestore(profile: UserProfile) {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        
        let profileData: [String: Any] = [
            "userId": profile.userId,
            "deviceId": deviceId,
            "name": profile.name,
            "email": profile.email,
            "phoneNumber": profile.phoneNumber,
            "version": profile.version,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt)
        ]
        
        print("Syncing profile to Firestore...")
        
        db.collection("user_profiles")
            .document("\(profile.userId)_v\(profile.version)")
            .setData(profileData) { error in
                if let error = error {
                    print("Failed to sync profile to Firestore: \(error)")
                } else {
                    print("Profile synced to Firestore successfully")
                }
            }
    }
    
    @objc private func viewProfileHistory() {
        let historyVC = ProfileListViewController()
        historyVC.userId = userId
        navigationController?.pushViewController(historyVC, animated: true)
    }
    
    private func saveImageToDocuments(_ image: UIImage, userId: String) -> String {
        let fileName = "\(userId)_profile_\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: filePath)
        }
        
        return fileName
    }
    
    private func loadImageFromDocuments(_ fileName: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = documentsPath.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: filePath.path)
    }
    
    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSuccessAlert(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}
