import UIKit
import FirebaseAuth
import FirebaseFirestore
import RealmSwift

class SecurityQuestionSetupViewController: UIViewController {
    
    var questions: [SecurityQuestion] = []
    var userId: String = ""
    var firebaseToken: String = ""
    
    private var selectedQuestion: SecurityQuestion?
    
    // MARK: - Constants
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    
    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.backgroundColor = UIColor.systemGroupedBackground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let shieldIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "shield.checkered")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Security Setup"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose one security question to protect your account"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let questionsLabel: UILabel = {
        let label = UILabel()
        label.text = "Select Your Security Question"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let questionsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let answerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0.5
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private let answerLabel: UILabel = {
        let label = UILabel()
        label.text = "Your Answer"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your answer here"
        tf.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        tf.backgroundColor = UIColor.systemGray6
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 2
        tf.layer.borderColor = UIColor.systemGray4.cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.rightViewMode = .always
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "Hint (Optional)"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let hintTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Add a helpful hint for yourself"
        tf.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        tf.backgroundColor = UIColor.systemGray6
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 2
        tf.layer.borderColor = UIColor.systemGray4.cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.rightViewMode = .always
        tf.returnKeyType = .done
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let setupButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Complete Security Setup", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 16
        btn.layer.shadowColor = UIColor.systemBlue.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.alpha = 0.5
        btn.isEnabled = false
        return btn
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Question Cards
    private var questionCards: [UIView] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        
        setupUI()
        setupQuestionCards()
        setupTargets()
        setupKeyboardHandling()
        
        print("SecurityQuestionSetupViewController loaded with \(questions.count) questions")
    }
    
    // MARK: - Keyboard Handling Setup
    private func setupKeyboardHandling() {
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Set text field delegates
        answerTextField.delegate = self
        hintTextField.delegate = self
        
        // Register for keyboard notifications
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
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight + 20, right: 0)
        
        scrollView.contentInset = contentInset
        scrollView.scrollIndicatorInsets = contentInset
        
        // Scroll to active text field
        if answerTextField.isFirstResponder {
            let rect = answerTextField.convert(answerTextField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect, animated: true)
        } else if hintTextField.isFirstResponder {
            let rect = hintTextField.convert(hintTextField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerView)
        headerView.addSubview(shieldIcon)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        contentView.addSubview(questionsContainerView)
        questionsContainerView.addSubview(questionsLabel)
        questionsContainerView.addSubview(questionsStackView)
        
        contentView.addSubview(answerContainerView)
        answerContainerView.addSubview(answerLabel)
        answerContainerView.addSubview(answerTextField)
        answerContainerView.addSubview(hintLabel)
        answerContainerView.addSubview(hintTextField)
        
        contentView.addSubview(setupButton)
        contentView.addSubview(loadingIndicator)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header View
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Shield Icon
            shieldIcon.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 24),
            shieldIcon.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            shieldIcon.widthAnchor.constraint(equalToConstant: 40),
            shieldIcon.heightAnchor.constraint(equalToConstant: 40),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: shieldIcon.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -24),
            
            // Questions Container
            questionsContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            questionsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            questionsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Questions Label
            questionsLabel.topAnchor.constraint(equalTo: questionsContainerView.topAnchor, constant: 20),
            questionsLabel.leadingAnchor.constraint(equalTo: questionsContainerView.leadingAnchor, constant: 20),
            questionsLabel.trailingAnchor.constraint(equalTo: questionsContainerView.trailingAnchor, constant: -20),
            
            // Questions Stack View
            questionsStackView.topAnchor.constraint(equalTo: questionsLabel.bottomAnchor, constant: 16),
            questionsStackView.leadingAnchor.constraint(equalTo: questionsContainerView.leadingAnchor, constant: 20),
            questionsStackView.trailingAnchor.constraint(equalTo: questionsContainerView.trailingAnchor, constant: -20),
            questionsStackView.bottomAnchor.constraint(equalTo: questionsContainerView.bottomAnchor, constant: -20),
            
            // Answer Container
            answerContainerView.topAnchor.constraint(equalTo: questionsContainerView.bottomAnchor, constant: 24),
            answerContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            answerContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Answer Label
            answerLabel.topAnchor.constraint(equalTo: answerContainerView.topAnchor, constant: 20),
            answerLabel.leadingAnchor.constraint(equalTo: answerContainerView.leadingAnchor, constant: 20),
            answerLabel.trailingAnchor.constraint(equalTo: answerContainerView.trailingAnchor, constant: -20),
            
            // Answer TextField
            answerTextField.topAnchor.constraint(equalTo: answerLabel.bottomAnchor, constant: 12),
            answerTextField.leadingAnchor.constraint(equalTo: answerContainerView.leadingAnchor, constant: 20),
            answerTextField.trailingAnchor.constraint(equalTo: answerContainerView.trailingAnchor, constant: -20),
            answerTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Hint Label
            hintLabel.topAnchor.constraint(equalTo: answerTextField.bottomAnchor, constant: 20),
            hintLabel.leadingAnchor.constraint(equalTo: answerContainerView.leadingAnchor, constant: 20),
            hintLabel.trailingAnchor.constraint(equalTo: answerContainerView.trailingAnchor, constant: -20),
            
            // Hint TextField
            hintTextField.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            hintTextField.leadingAnchor.constraint(equalTo: answerContainerView.leadingAnchor, constant: 20),
            hintTextField.trailingAnchor.constraint(equalTo: answerContainerView.trailingAnchor, constant: -20),
            hintTextField.heightAnchor.constraint(equalToConstant: 50),
            hintTextField.bottomAnchor.constraint(equalTo: answerContainerView.bottomAnchor, constant: -20),
            
            // Setup Button
            setupButton.topAnchor.constraint(equalTo: answerContainerView.bottomAnchor, constant: 32),
            setupButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            setupButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            setupButton.heightAnchor.constraint(equalToConstant: 56),
            setupButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            
            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: setupButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: setupButton.centerYAnchor)
        ])
    }
    
    private func setupQuestionCards() {
        for (index, question) in questions.enumerated() {
            let cardView = createQuestionCard(for: question, index: index)
            questionsStackView.addArrangedSubview(cardView)
            questionCards.append(cardView)
        }
    }
    
    private func createQuestionCard(for question: SecurityQuestion, index: Int) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIColor.systemGray6
        cardView.layer.cornerRadius = 12
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = UIColor.systemGray4.cgColor
        cardView.tag = index
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: getIconForQuestion(question))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let questionLabel = UILabel()
        questionLabel.text = question.questionText
        questionLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        questionLabel.textColor = .label
        questionLabel.numberOfLines = 0
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let categoryLabel = UILabel()
        categoryLabel.text = question.category
        categoryLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        categoryLabel.textColor = .secondaryLabel
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let checkmarkView = UIImageView()
        checkmarkView.image = UIImage(systemName: "circle")
        checkmarkView.tintColor = .systemGray3
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(iconView)
        cardView.addSubview(questionLabel)
        cardView.addSubview(categoryLabel)
        cardView.addSubview(checkmarkView)
        
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 80),
            
            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            questionLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            questionLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            questionLabel.trailingAnchor.constraint(equalTo: checkmarkView.leadingAnchor, constant: -12),
            
            categoryLabel.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            categoryLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 4),
            categoryLabel.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),
            categoryLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),
            
            checkmarkView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            checkmarkView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(questionCardTapped(_:)))
        cardView.addGestureRecognizer(tapGesture)
        cardView.isUserInteractionEnabled = true
        
        return cardView
    }
    
    private func getIconForQuestion(_ question: SecurityQuestion) -> String {
        switch question.questionId {
        case "personal_memory":
            return "heart.fill"
        case "personal_preference":
            return "star.fill"
        case "childhood_memory":
            return "graduationcap.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private func setupTargets() {
        setupButton.addTarget(self, action: #selector(setupButtonTapped), for: .touchUpInside)
        answerTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    // MARK: - Actions
    @objc private func questionCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view else { return }
        let index = cardView.tag
        selectedQuestion = questions[index]
        
        // Update UI for selection
        updateQuestionSelection(selectedIndex: index)
        
        // Enable answer container
        UIView.animate(withDuration: 0.3) {
            self.answerContainerView.alpha = 1.0
            self.answerContainerView.isUserInteractionEnabled = true
        }
        
        // Focus on answer field
        answerTextField.becomeFirstResponder()
        
        print("Selected question: \(questions[index].questionText)")
    }
    
    @objc private func textFieldDidChange() {
        updateSetupButtonState()
    }
    
    private func updateQuestionSelection(selectedIndex: Int) {
        for (index, cardView) in questionCards.enumerated() {
            let checkmarkView = cardView.subviews.last as? UIImageView
            
            if index == selectedIndex {
                // Selected state
                cardView.layer.borderColor = UIColor.systemBlue.cgColor
                cardView.layer.borderWidth = 3
                cardView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                checkmarkView?.image = UIImage(systemName: "checkmark.circle.fill")
                checkmarkView?.tintColor = .systemBlue
            } else {
                // Unselected state
                cardView.layer.borderColor = UIColor.systemGray4.cgColor
                cardView.layer.borderWidth = 2
                cardView.backgroundColor = UIColor.systemGray6
                checkmarkView?.image = UIImage(systemName: "circle")
                checkmarkView?.tintColor = .systemGray3
            }
        }
    }
    
    private func updateSetupButtonState() {
        let hasSelectedQuestion = selectedQuestion != nil
        let hasAnswer = !(answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        let isEnabled = hasSelectedQuestion && hasAnswer
        
        UIView.animate(withDuration: 0.2) {
            self.setupButton.alpha = isEnabled ? 1.0 : 0.5
            self.setupButton.isEnabled = isEnabled
        }
    }
    
    // MARK: - Setup Submission
    // MARK: - Setup Submission
    @objc private func setupButtonTapped() {
        view.endEditing(true)
        
        guard let question = selectedQuestion else {
            showAlert(message: "Please select a security question.")
            return
        }
        
        guard let answer = answerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !answer.isEmpty else {
            showAlert(message: "Please enter your answer.")
            return
        }
        
        let hint = hintTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        setupButton.setTitle("", for: .normal)
        loadingIndicator.startAnimating()
        setupButton.isEnabled = false
        
        // ✅ GET REAL FIREBASE TOKEN
        Auth.auth().currentUser?.getIDToken { [weak self] token, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Failed to get Firebase token: \(error)")
                self.resetButtonState()
                self.showAlert(message: "Authentication error. Please try again.")
                return
            }
            
            guard let firebaseToken = token else {
                print("❌ No Firebase token available")
                self.resetButtonState()
                self.showAlert(message: "Authentication error. Please sign in again.")
                return
            }
            
            print("✅ Got Firebase token: \(firebaseToken.prefix(20))...")
            
            // ✅ NOW SUBMIT WITH REAL TOKEN
            let body: [String: Any] = [
                "user_id": self.userId,
                "selected_question_id": question.questionId,
                "question_text": question.questionText,
                "user_answer": answer,
                "hint": hint,
                "firebase_token": firebaseToken  // ✅ Real token
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                self.resetButtonState()
                self.showAlert(message: "Failed to encode request.")
                return
            }

            guard let url = URL(string: "\(self.baseURL)/security/setup") else {
                self.resetButtonState()
                self.showAlert(message: "Invalid URL.")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData

            print("[SETUP] Submitting security question setup")
            print("[SETUP] Question: \(question.questionText)")
            print("[SETUP] Answer: \(answer)")
            print("[SETUP] UserId: \(self.userId)")
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[SETUP] Request Body (token redacted for security)")
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    self.resetButtonState()
                    
                    if let error = error {
                        print("❌ [SETUP] Network Error: \(error.localizedDescription)")
                        self.showAlert(message: "Network Error: \(error.localizedDescription)")
                        return
                    }

                    if let httpResponse = response as? HTTPURLResponse {
                        print("📡 [SETUP] Response Code: \(httpResponse.statusCode)")
                        
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("📦 [SETUP] Response Body: \(responseString)")
                        }
                        
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                            print("✅ [SETUP] Security question saved successfully")
                            self.updateFirestoreSecurityFlag {
                                self.checkRealmDatabase()
                                self.showSuccessAndNavigate()
                            }
                        } else {
                            let errorMsg = data != nil ? String(data: data!, encoding: .utf8) ?? "Unknown error" : "Server Error"
                            print("❌ [SETUP] Failed: \(errorMsg)")
                            self.showAlert(message: "Setup Failed (\(httpResponse.statusCode)): \(errorMsg)")
                        }
                    }
                }
            }.resume()
        }
    }



    private func resetButtonState() {
        setupButton.setTitle("Complete Security Setup", for: .normal)
        loadingIndicator.stopAnimating()
        setupButton.isEnabled = true
    }
    
    private func showSuccessAndNavigate() {
        let alert = UIAlertController(
            title: "✅ Setup Complete!",
            message: "Your security question has been configured successfully. Your account is now protected.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            self.navigateToHome()
        })
        present(alert, animated: true)
    }
    
    // MARK: - Firestore Update
    private func updateFirestoreSecurityFlag(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(userId)
        
        let updateData: [String: Any] = [
            "security_setup_complete": true,  // ✅ Correct - snake_case
            "security_setup_timestamp": FieldValue.serverTimestamp(),
            "email": Auth.auth().currentUser?.email ?? ""  // ✅ Also set email
        ]
        
        userDoc.setData(updateData, merge: true) { error in
            if let error = error {
                print("❌ Failed to update Firestore flag: \(error)")
            } else {
                print("✅ Successfully updated security_setup_complete = true")
            }
            DispatchQueue.main.async { completion() }
        }
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
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Security Setup", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // ✅ NEW: Check Realm Database for Gyroscope Data
    private func checkRealmDatabase() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            do {
                let realm = try Realm()
                
                print("\n" + String(repeating: "=", count: 70))
                print("📊 REALM DATABASE CHECK - GYROSCOPE DATA")
                print(String(repeating: "=", count: 70))
                
                // Get file URL
                let realmURL = Realm.Configuration.defaultConfiguration.fileURL
                print("📁 Realm Location: \(realmURL?.path ?? "Unknown")")
                print("")
                
                // Check TrustSnapshots
                let snapshots = realm.objects(TrustSnapshot.self).sorted(byKeyPath: "timestamp", ascending: false)
                print("📊 Total Snapshots Found: \(snapshots.count)")
                print("")
                
                if snapshots.isEmpty {
                    print("⚠️ No snapshots found in database yet")
                } else {
                    for (index, snapshot) in snapshots.prefix(5).enumerated() {
                        print("Snapshot #\(index + 1) (Most Recent):")
                        print("  🆔 User: \(snapshot.userId)")
                        print("  📱 Device: \(snapshot.deviceId)")
                        print("  ⏰ Timestamp: \(snapshot.timestamp)")
                        print("")
                        print("  🎯 GYROSCOPE DATA:")
                        print("     Motion State: \(snapshot.motionStateRaw)")
                        print("     Motion Magnitude: \(String(format: "%.6f", snapshot.motionMagnitude))")
                        print("")
                        print("  🔒 Security Signals:")
                        print("     User Interacting: \(snapshot.isUserInteracting)")
                        print("     Jailbroken: \(snapshot.isJailbroken)")
                        print("     VPN Enabled: \(snapshot.isVPNEnabled)")
                        print("")
                        print("  📊 Trust Level: \(snapshot.trustLevel)/100")
                        print("  🏷️ Flags: \(snapshot.flags ?? "none")")
                        print("  📍 Location: \(snapshot.location)")
                        print("  🌐 Timezone: \(snapshot.timezone)")
                        print("  🔄 Sync Status: \(snapshot.syncStatusRaw)")
                        print(String(repeating: "-", count: 70))
                    }
                }
                
                // Check TrustBaseline
                let baselines = realm.objects(TrustBaseline.self)
                print("\n📋 Baselines Found: \(baselines.count)")
                for baseline in baselines {
                    print("  User: \(baseline.userId)")
                    print("  Email: \(baseline.email)")
                    print("  Device: \(baseline.deviceId)")
                    print("  Timezone: \(baseline.timezone)")
                }
                
                print("\n" + String(repeating: "=", count: 70))
                print("✅ REALM CHECK COMPLETE")
                print(String(repeating: "=", count: 70) + "\n")
                
            } catch {
                print("❌ Error accessing Realm: \(error)")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextFieldDelegate Extension
extension SecurityQuestionSetupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == answerTextField {
            hintTextField.becomeFirstResponder()
        } else if textField == hintTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}
