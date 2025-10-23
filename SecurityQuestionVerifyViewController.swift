//
//  SecurityQuestionVerifyViewController.swift
//  Userapp
//
//  Created by Ri on 8/25/25.
//


import UIKit

// MARK: - Layout 2: Verification (Device Change/Low Trust/Re-login)
class SecurityQuestionVerifyViewController: UIViewController {
    
    var userId: String = ""
    var reason: String = ""
    private var questionData: SecurityQuestionData?
    
    // MARK: - UI Elements
    private let alertIcon: UILabel = {
        let label = UILabel()
        label.text = "⚠️"
        label.font = UIFont.systemFont(ofSize: 50)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "🔐 Security Verification Required"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .systemRed
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemOrange
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let instructionsLabel: UILabel = {
        let label = UILabel()
        label.text = "Please answer your security question to continue"
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.numberOfLines = 0
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your answer"
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 18)
        tf.backgroundColor = UIColor.systemBackground
        tf.layer.borderWidth = 2
        tf.layer.borderColor = UIColor.systemBlue.cgColor
        tf.layer.cornerRadius = 10
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let verifyButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🔓 Verify & Continue", for: .normal)
        btn.backgroundColor = .systemGreen
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
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
        
        print("🔐 SecurityQuestionVerifyViewController - Verification Mode")
        print("🚨 Verification reason: \(reason)")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        reasonLabel.text = "🚨 \(reason.uppercased())"
        
        // Add question container setup
        questionContainerView.addSubview(questionLabel)
        questionContainerView.addSubview(hintLabel)
        
        view.addSubview(alertIcon)
        view.addSubview(titleLabel)
        view.addSubview(reasonLabel)
        view.addSubview(instructionsLabel)
        view.addSubview(questionContainerView)
        view.addSubview(answerTextField)
        view.addSubview(verifyButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            // Alert Icon
            alertIcon.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            alertIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: alertIcon.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Reason
            reasonLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            reasonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            reasonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Instructions
            instructionsLabel.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 20),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Question Container
            questionContainerView.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 30),
            questionContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            questionContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Question Label inside container
            questionLabel.topAnchor.constraint(equalTo: questionContainerView.topAnchor, constant: 15),
            questionLabel.leadingAnchor.constraint(equalTo: questionContainerView.leadingAnchor, constant: 15),
            questionLabel.trailingAnchor.constraint(equalTo: questionContainerView.trailingAnchor, constant: -15),
            
            // Hint Label inside container
            hintLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 10),
            hintLabel.leadingAnchor.constraint(equalTo: questionContainerView.leadingAnchor, constant: 15),
            hintLabel.trailingAnchor.constraint(equalTo: questionContainerView.trailingAnchor, constant: -15),
            hintLabel.bottomAnchor.constraint(equalTo: questionContainerView.bottomAnchor, constant: -15),
            
            // Answer TextField
            answerTextField.topAnchor.constraint(equalTo: questionContainerView.bottomAnchor, constant: 30),
            answerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            answerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            answerTextField.heightAnchor.constraint(equalToConstant: 55),
            
            // Verify Button
            verifyButton.topAnchor.constraint(equalTo: answerTextField.bottomAnchor, constant: 30),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            verifyButton.widthAnchor.constraint(equalToConstant: 250),
            verifyButton.heightAnchor.constraint(equalToConstant: 55),
            
            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20)
        ])
        
        verifyButton.addTarget(self, action: #selector(verifyButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Load Security Question
    private func loadSecurityQuestion() {
        loadingIndicator.startAnimating()
        questionLabel.text = "Loading your security question..."
        
        TrustSecurityManager.shared.getUserSecurityQuestion(for: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let questionData):
                    self?.questionData = questionData
                    self?.questionLabel.text = "❓ \(questionData.questionText)"
                    
                    if let hint = questionData.hint, !hint.isEmpty {
                        self?.hintLabel.text = "💡 Hint: \(hint)"
                        self?.hintLabel.isHidden = false
                    } else {
                        self?.hintLabel.text = "💡 No hint available"
                        self?.hintLabel.isHidden = false
                    }
                    
                case .failure(let error):
                    print("❌ [VERIFY] Failed to load question: \(error)")
                    self?.showAlert(title: "Error", message: "Failed to load security question. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Verify Answer
    @objc private func verifyButtonTapped() {
        guard let answer = answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            showAlert(title: "Missing Answer", message: "Please enter your answer")
            return
        }
        
        verifyButton.isEnabled = false
        verifyButton.setTitle("Verifying...", for: .normal)
        loadingIndicator.startAnimating()
        
        TrustSecurityManager.shared.verifySecurityAnswer(userId: userId, answer: answer) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.verifyButton.isEnabled = true
                self?.verifyButton.setTitle("🔓 Verify & Continue", for: .normal)
                self?.loadingIndicator.stopAnimating()
                
                if success {
                    // Reset trust and navigate to home
                    TrustSecurityManager.shared.resetTrustScore(for: self?.userId ?? "")
                    self?.showSuccessAndNavigate()
                } else {
                    self?.showAlert(title: "❌ Verification Failed", message: message ?? "Incorrect answer. Please try again.")
                    self?.answerTextField.text = ""
                    // Add red border for failed attempt
                    self?.answerTextField.layer.borderColor = UIColor.systemRed.cgColor
                    
                    // Reset border color after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.answerTextField.layer.borderColor = UIColor.systemBlue.cgColor
                    }
                }
            }
        }
    }
    
    private func showSuccessAndNavigate() {
        let alert = UIAlertController(title: "✅ Verified!", message: "Security verification successful. Welcome back!", preferredStyle: .alert)
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