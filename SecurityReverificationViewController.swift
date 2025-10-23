//
//  SecurityReverificationViewController.swift
//  Userapp
//
//  Created by Ri on 8/25/25.
//


import UIKit

class SecurityReverificationViewController: UIViewController {
    
    var userId: String = ""
    var reason: String = ""
    private var questionData: SecurityQuestionData?
    
    // MARK: - UI Elements
    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Security Verification Required"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .systemBlue
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your answer"
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 16)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let verifyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Verify", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        loadSecurityQuestion()
        
        // Prevent dismissal
        isModalInPresentation = true
        navigationItem.hidesBackButton = true
        
        print("🔐 Security reverification triggered: \(reason)")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        reasonLabel.text = "⚠️ \(reason)"
        
        view.addSubview(titleLabel)
        view.addSubview(reasonLabel)
        view.addSubview(questionLabel)
        view.addSubview(hintLabel)
        view.addSubview(answerTextField)
        view.addSubview(verifyButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            reasonLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            reasonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            reasonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            questionLabel.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            hintLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 10),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            answerTextField.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 30),
            answerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            answerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            answerTextField.heightAnchor.constraint(equalToConstant: 50),
            
            verifyButton.topAnchor.constraint(equalTo: answerTextField.bottomAnchor, constant: 30),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            verifyButton.widthAnchor.constraint(equalToConstant: 200),
            verifyButton.heightAnchor.constraint(equalToConstant: 50),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20)
        ])
        
        verifyButton.addTarget(self, action: #selector(verifyButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Load Security Question
    private func loadSecurityQuestion() {
        loadingIndicator.startAnimating()
        
        TrustSecurityManager.shared.getUserSecurityQuestion(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let questionData):
                    self?.questionData = questionData
                    self?.questionLabel.text = questionData.questionText
                    
                    if let hint = questionData.hint, !hint.isEmpty {
                        self?.hintLabel.text = "Hint: \(hint)"
                        self?.hintLabel.isHidden = false
                    } else {
                        self?.hintLabel.isHidden = true
                    }
                    
                case .failure(let error):
                    print("❌ Failed to load question: \(error)")
                    self?.showAlert(title: "Error", message: "Failed to load security question. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Verify Answer
    @objc private func verifyButtonTapped() {
        guard let answer = answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            showAlert(title: "Error", message: "Please enter your answer")
            return
        }
        
        verifyButton.isEnabled = false
        loadingIndicator.startAnimating()
        
        TrustSecurityManager.shared.verifySecurityAnswer(userId: userId, answer: answer) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.verifyButton.isEnabled = true
                self?.loadingIndicator.stopAnimating()
                
                if success {
                    // Reset trust and navigate to home
                    TrustSecurityManager.shared.resetTrustScore(for: self?.userId ?? "")
                    self?.showSuccessAndNavigate()
                } else {
                    self?.showAlert(title: "Verification Failed", message: message ?? "Incorrect answer. Please try again.")
                    self?.answerTextField.text = ""
                }
            }
        }
    }
    
    private func showSuccessAndNavigate() {
        let alert = UIAlertController(title: "Verified!", message: "Security verification successful", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.navigateToHome()
        })
        present(alert, animated: true)
    }
    
    private func navigateToHome() {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            let homeVC = HomeViewController()
            let navController = UINavigationController(rootViewController: homeVC)
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
