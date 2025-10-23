import UIKit

class SingleSecurityQuestionViewController: UIViewController {
    
    var userId: String = ""
    var firebaseToken: String = ""
    var questionData: SecurityQuestionData?
    var verificationReason: String = "Security verification required" // New property
    
    // MARK: - Constants
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    
    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Security Verification"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
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
    
    private let submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Submit", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
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
        loadUserSecurityQuestion()
        
        print("SingleSecurityQuestion loaded for userId: \(userId)")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(instructionsLabel)
        view.addSubview(questionLabel)
        view.addSubview(hintLabel)
        view.addSubview(answerTextField)
        view.addSubview(submitButton)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Instructions
            instructionsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Question
            questionLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 40),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Hint
            hintLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 15),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Answer TextField
            answerTextField.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 30),
            answerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            answerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            answerTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Submit Button
            submitButton.topAnchor.constraint(equalTo: answerTextField.bottomAnchor, constant: 30),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 200),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 20)
        ])
        
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Load User's Security Question
    private func loadUserSecurityQuestion() {
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
                    print("Failed to load user question: \(error)")
                    self?.showAlert(title: "Error", message: "Failed to load your security question. Please try again.")
                }
            }
        }
    }
    
    // MARK: - Submit Answer
    @objc private func submitButtonTapped() {
        guard let answer = answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            showAlert(title: "Error", message: "Please enter your answer")
            return
        }
        
        submitButton.isEnabled = false
        submitButton.setTitle("Verifying...", for: .normal)
        loadingIndicator.startAnimating()
        
        // Use the TrustSecurityManager to verify the answer
        TrustSecurityManager.shared.verifySecurityAnswer(userId: userId, answer: answer) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.submitButton.isEnabled = true
                self?.submitButton.setTitle("Submit", for: .normal)
                self?.loadingIndicator.stopAnimating()
                
                if success {
                    self?.showSuccessAndNavigate()
                } else {
                    self?.showAlert(title: "Verification Failed", message: message ?? "Incorrect answer. Please try again.")
                    self?.answerTextField.text = ""
                }
            }
        }
    }
    
    private func showSuccessAndNavigate() {
        let alert = UIAlertController(title: "Success", message: "Welcome back!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.navigateToHome()
        })
        present(alert, animated: true)
    }
    
    private func navigateToHome() {
        let homeVC = HomeViewController()
        let navController = UINavigationController(rootViewController: homeVC)
        navController.modalPresentationStyle = .fullScreen
        
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        } else {
            self.present(navController, animated: true, completion: nil)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
