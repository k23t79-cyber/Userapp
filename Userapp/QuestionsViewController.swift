import UIKit

// ✅ Fixed SecurityQuestion model to match your ACTUAL API response
struct SecurityQuestion: Codable {
    let questionId: String    // Maps to "question_id"
    let questionText: String  // Maps to "question_text"
    let category: String      // Maps to "category"
    
    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case questionText = "question_text"
        case category
    }
}

class QuestionsViewController: UIViewController, UITextViewDelegate {
    
    var question: SecurityQuestion?
    var userId: String = ""          // inject this from LoginViewController
    var firebaseToken: String = ""   // inject this if needed for auth
    
    // MARK: - Constants
    private let baseURL = "https://firebase-security-backend-514931815167.us-central1.run.app"
    
    private let questionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let instructionsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let answerTextView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.layer.borderColor = UIColor.lightGray.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let hintTextView: UITextView = {
        let tv = UITextView()
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.layer.borderColor = UIColor.lightGray.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 8
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let submitButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Submit Answer", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        
        if let q = question {
            questionLabel.text = q.questionText
            answerTextView.text = "Enter your answer here..."
            answerTextView.textColor = .placeholderText
            
            hintTextView.text = "Enter a helpful hint (optional)..."
            hintTextView.textColor = .placeholderText
        }
        
        // Debug: Print userId to make sure it's set
        print("🔍 QuestionsViewController userId: \(userId)")
    }
    
    private func setupUI() {
        // Create labels
        let answerLabel = UILabel()
        answerLabel.text = "Your Answer:"
        answerLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        answerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let hintLabel = UILabel()
        hintLabel.text = "Helpful Hint (optional):"
        hintLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(questionLabel)
        view.addSubview(instructionsLabel)
        view.addSubview(answerLabel)
        view.addSubview(answerTextView)
        view.addSubview(hintLabel)
        view.addSubview(hintTextView)
        view.addSubview(submitButton)
        
        // Set up text view delegates for placeholder handling
        answerTextView.delegate = self
        hintTextView.delegate = self
        
        NSLayoutConstraint.activate([
            questionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            questionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            instructionsLabel.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 10),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            answerLabel.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 20),
            answerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            answerTextView.topAnchor.constraint(equalTo: answerLabel.bottomAnchor, constant: 8),
            answerTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            answerTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            answerTextView.heightAnchor.constraint(equalToConstant: 80),
            
            hintLabel.topAnchor.constraint(equalTo: answerTextView.bottomAnchor, constant: 15),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            hintTextView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            hintTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hintTextView.heightAnchor.constraint(equalToConstant: 80),
            
            submitButton.topAnchor.constraint(equalTo: hintTextView.bottomAnchor, constant: 30),
            submitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 200),
            submitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        
        // Set instructions text
        instructionsLabel.text = "Choose one question, provide your answer and a helpful hint. Your answer will be encrypted with AES-256-GCM and stored securely."
    }
    
    // 🔒 Cloud Run API call - FINAL FIXED VERSION
    @objc private func submitButtonTapped() {
        guard let q = question else {
            showAlert(message: "Question not found.")
            return
        }
        
        // Check if user entered a real answer (not placeholder text)
        let userAnswer = answerTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !userAnswer.isEmpty && userAnswer != "Enter your answer here..." else {
            showAlert(message: "Please enter your answer.")
            return
        }
        
        guard !userId.isEmpty else {
            showAlert(message: "User ID is missing.")
            return
        }

        // Get hint text (empty string if it's still placeholder)
        let hintText = hintTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalHint = (hintText == "Enter a helpful hint (optional)...") ? "" : hintText

        // ✅ FIXED: Backend expects "user_answer" not "answer"
        let body: [String: Any] = [
            "user_id": userId,
            "selected_question_id": q.questionId,
            "user_answer": userAnswer,              // ← KEY FIX: user_answer instead of answer
            "hint": finalHint,
            "firebase_token": firebaseToken
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            showAlert(message: "Failed to encode request.")
            return
        }

        guard let url = URL(string: "\(baseURL)/security/setup") else {
            showAlert(message: "Invalid URL.")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        print("📤 Sending request to: \(url.absoluteString)")
        print("📤 Request body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")

        // API Call
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showAlert(message: "Network Error: \(error.localizedDescription)")
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Response Code: \(httpResponse.statusCode)")
                
                // Print response body for debugging
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 Response Body: \(responseString)")
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    DispatchQueue.main.async {
                        let alert = UIAlertController(
                            title: "Success",
                            message: "Your security question was saved successfully!",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self.navigateToHome()
                        })
                        self.present(alert, animated: true)
                    }
                } else {
                    DispatchQueue.main.async {
                        let errorMsg = data != nil ? String(data: data!, encoding: .utf8) ?? "Unknown error" : "Server Error"
                        self.showAlert(message: "Server Error (\(httpResponse.statusCode)): \(errorMsg)")
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - UITextViewDelegate for placeholder handling
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView == answerTextView && textView.text == "Enter your answer here..." {
            textView.text = ""
            textView.textColor = .label
        } else if textView == hintTextView && textView.text == "Enter a helpful hint (optional)..." {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == answerTextView && textView.text.isEmpty {
            textView.text = "Enter your answer here..."
            textView.textColor = .placeholderText
        } else if textView == hintTextView && textView.text.isEmpty {
            textView.text = "Enter a helpful hint (optional)..."
            textView.textColor = .placeholderText
        }
    }
    
    private func navigateToHome() {
        // Navigate to HomeViewController
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
        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
