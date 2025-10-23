import UIKit
import FirebaseAuth

class SecurityVerificationViewController: UIViewController {
    
    var userId: String = ""
    var firebaseToken: String = ""
    private var storedQuestion: StoredSecurityQuestion?
    private var availableQuestions: [StoredSecurityQuestion] = []
    
    // MARK: - UI Elements
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.15
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 20
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.shield.fill")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Security Verification"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Please answer your security question to verify your identity"
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = .center
        label.textColor = .white.withAlphaComponent(0.95)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let formContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6.withAlphaComponent(0.5)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "questionmark.circle.fill")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your Answer"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your answer"
        textField.backgroundColor = .systemBackground
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 2
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.textColor = .label
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        
        // Add padding
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.rightViewMode = .always
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Verify Identity", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Use Limited Access", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemBlue
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let loadingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupUI()
        setupKeyboardHandling()
        loadSecurityQuestion()
        
        // Prevent dismissal
        isModalInPresentation = true
        
        // Setup text field delegate
        answerTextField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Auto-focus text field after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.answerTextField.becomeFirstResponder()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Add scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(containerView)
        
        // Add header
        containerView.addSubview(headerView)
        headerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        // Add form elements
        containerView.addSubview(formContainerView)
        formContainerView.addSubview(questionContainerView)
        questionContainerView.addSubview(questionIconView)
        questionContainerView.addSubview(questionLabel)
        
        formContainerView.addSubview(answerTitleLabel)
        formContainerView.addSubview(answerTextField)
        formContainerView.addSubview(verifyButton)
        formContainerView.addSubview(cancelButton)
        
        // Add loading overlay
        containerView.addSubview(loadingOverlay)
        loadingOverlay.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Container
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            
            // Header
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 140),
            
            iconImageView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // Form Container
            formContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 28),
            formContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            formContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            formContainerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -28),
            
            // Question Container
            questionContainerView.topAnchor.constraint(equalTo: formContainerView.topAnchor),
            questionContainerView.leadingAnchor.constraint(equalTo: formContainerView.leadingAnchor),
            questionContainerView.trailingAnchor.constraint(equalTo: formContainerView.trailingAnchor),
            
            questionIconView.topAnchor.constraint(equalTo: questionContainerView.topAnchor, constant: 16),
            questionIconView.leadingAnchor.constraint(equalTo: questionContainerView.leadingAnchor, constant: 16),
            questionIconView.widthAnchor.constraint(equalToConstant: 24),
            questionIconView.heightAnchor.constraint(equalToConstant: 24),
            
            questionLabel.topAnchor.constraint(equalTo: questionContainerView.topAnchor, constant: 16),
            questionLabel.leadingAnchor.constraint(equalTo: questionIconView.trailingAnchor, constant: 12),
            questionLabel.trailingAnchor.constraint(equalTo: questionContainerView.trailingAnchor, constant: -16),
            questionLabel.bottomAnchor.constraint(equalTo: questionContainerView.bottomAnchor, constant: -16),
            
            // Answer Section
            answerTitleLabel.topAnchor.constraint(equalTo: questionContainerView.bottomAnchor, constant: 24),
            answerTitleLabel.leadingAnchor.constraint(equalTo: formContainerView.leadingAnchor, constant: 4),
            
            answerTextField.topAnchor.constraint(equalTo: answerTitleLabel.bottomAnchor, constant: 8),
            answerTextField.leadingAnchor.constraint(equalTo: formContainerView.leadingAnchor),
            answerTextField.trailingAnchor.constraint(equalTo: formContainerView.trailingAnchor),
            answerTextField.heightAnchor.constraint(equalToConstant: 54),
            
            // Buttons
            verifyButton.topAnchor.constraint(equalTo: answerTextField.bottomAnchor, constant: 28),
            verifyButton.leadingAnchor.constraint(equalTo: formContainerView.leadingAnchor),
            verifyButton.trailingAnchor.constraint(equalTo: formContainerView.trailingAnchor),
            verifyButton.heightAnchor.constraint(equalToConstant: 54),
            
            cancelButton.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: formContainerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: formContainerView.bottomAnchor),
            
            // Loading Overlay
            loadingOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor)
        ])
        
        // Add button actions
        verifyButton.addTarget(self, action: #selector(verifyButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Initially hide content
        hideContent()
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight + 20, right: 0)
        
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
        
        // Scroll to answer text field
        let textFieldFrame = answerTextField.convert(answerTextField.bounds, to: scrollView)
        scrollView.scrollRectToVisible(textFieldFrame, animated: true)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Content Animation
    
    private func hideContent() {
        formContainerView.alpha = 0
        loadingOverlay.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    private func showContent() {
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.formContainerView.alpha = 1
            self.loadingOverlay.isHidden = true
        }
        loadingIndicator.stopAnimating()
    }
    
    // MARK: - Data Loading
    
    private func loadSecurityQuestion() {
        TrustScoreManager.shared.getUserSecurityQuestion(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let question):
                    self?.storedQuestion = question
                    self?.questionLabel.text = question.question
                    self?.showContent()
                    
                case .failure(let error):
                    self?.showErrorAndDismiss("Failed to load security question: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func verifyButtonTapped() {
        // Dismiss keyboard first
        view.endEditing(true)
        
        guard let answer = answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            shakeTextField()
            showAlert("Please enter your answer", title: "Missing Answer")
            return
        }
        
        setLoadingState(true)
        
        TrustScoreManager.shared.verifySecurityAnswer(
            userId: userId,
            answer: answer,
            firebaseToken: firebaseToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoadingState(false)
                
                switch result {
                case .success(let isValid):
                    if isValid {
                        self?.handleSuccessfulVerification()
                    } else {
                        self?.handleFailedVerification()
                    }
                    
                case .failure(let error):
                    self?.showAlert("Verification failed: \(error.localizedDescription)", title: "Error")
                }
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        let alert = UIAlertController(
            title: "Limited Access Mode",
            message: "You will have restricted access to the app until you complete security verification. Some features may be unavailable.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue with Limited Access", style: .destructive) { _ in
            self.dismiss(animated: true) {
                self.navigateToLimitedAccess()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - UI State Management
    
    private func setLoadingState(_ isLoading: Bool) {
        verifyButton.isEnabled = !isLoading
        answerTextField.isEnabled = !isLoading
        cancelButton.isEnabled = !isLoading
        
        if isLoading {
            loadingOverlay.isHidden = false
            loadingIndicator.startAnimating()
        } else {
            loadingOverlay.isHidden = true
            loadingIndicator.stopAnimating()
        }
    }
    
    private func shakeTextField() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.duration = 0.5
        shake.values = [-15.0, 15.0, -12.0, 12.0, -8.0, 8.0, -4.0, 4.0, 0.0]
        answerTextField.layer.add(shake, forKey: "shake")
        
        // Flash border red
        UIView.animate(withDuration: 0.1, animations: {
            self.answerTextField.layer.borderColor = UIColor.systemRed.cgColor
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseOut) {
                self.answerTextField.layer.borderColor = UIColor.systemGray5.cgColor
            }
        }
    }
    
    // MARK: - Verification Handling
    
    private func handleSuccessfulVerification() {
        // Success haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Flash green
        UIView.animate(withDuration: 0.2, animations: {
            self.answerTextField.layer.borderColor = UIColor.systemGreen.cgColor
            self.answerTextField.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        })
        
        let alert = UIAlertController(
            title: "✓ Verification Successful",
            message: "Your identity has been verified successfully. Full access has been restored.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.dismiss(animated: true) {
                self.navigateToHome()
            }
        })
        
        present(alert, animated: true)
    }
    
    private func handleFailedVerification() {
        // Error haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        shakeTextField()
        answerTextField.text = ""
        
        let alert = UIAlertController(
            title: "Verification Failed",
            message: "The answer you provided doesn't match our records. Please check your answer and try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            self.answerTextField.layer.borderColor = UIColor.systemGray5.cgColor
            self.answerTextField.backgroundColor = .systemBackground
            self.answerTextField.becomeFirstResponder()
        })
        
        alert.addAction(UIAlertAction(title: "Use Limited Access", style: .destructive) { _ in
            self.cancelButtonTapped()
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToHome() {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            let homeVC = HomeViewController()
            let navController = UINavigationController(rootViewController: homeVC)
            sceneDelegate.window?.rootViewController = navController
            sceneDelegate.window?.makeKeyAndVisible()
        }
    }
    
    private func navigateToLimitedAccess() {
        navigateToHome()
    }
    
    // MARK: - Alerts
    
    private func showAlert(_ message: String, title: String = "Security Verification") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAndDismiss(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextFieldDelegate

extension SecurityVerificationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        verifyButtonTapped()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.2) {
            textField.layer.borderColor = UIColor.systemBlue.cgColor
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        UIView.animate(withDuration: 0.2) {
            textField.layer.borderColor = UIColor.systemGray5.cgColor
        }
    }
}

// MARK: - Factory Method

extension SecurityVerificationViewController {
    static func create(userId: String, firebaseToken: String) -> SecurityVerificationViewController {
        let vc = SecurityVerificationViewController()
        vc.userId = userId
        vc.firebaseToken = firebaseToken
        vc.modalPresentationStyle = .overFullScreen
        return vc
    }
}
