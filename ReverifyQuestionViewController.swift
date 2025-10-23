
import UIKit
import CryptoKit
import FirebaseFirestore
class ReverifyQuestionViewController: UIViewController {
    var userId: String = ""
    var question: String = ""
    let answerField = UITextField()
    let verifyButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        fetchQuestion()
    }
    
    func setupUI() {
        answerField.placeholder = "Enter your answer"
        answerField.borderStyle = .roundedRect
        verifyButton.setTitle("Verify", for: .normal)
        verifyButton.addTarget(self, action: #selector(verifyAnswer), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [answerField, verifyButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    func fetchQuestion() {
        guard let url = URL(string: "https://firebase-security-backend-514931815167.us-central1.run.app/user/get?uid=\(userId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let q = json["securityQuestion"] as? String {
                DispatchQueue.main.async {
                    self.question = q
                    self.title = q
                }
            }
        }.resume()
    }
    
    @objc func verifyAnswer() {
        guard let answer = answerField.text, !answer.isEmpty else { return }
        
        let hashValue = hashQuestionAnswer(question: question, answer: answer)
        Firestore.firestore().collection("users").document(userId).getDocument { doc, _ in
            if let storedHash = doc?.data()?["qaHash"] as? String, storedHash == hashValue {
                print("✅ Verification success")
            } else {
                print("❌ Verification failed")
            }
        }
    }
    
    func hashQuestionAnswer(question: String, answer: String) -> String {
        let input = "\(question.lowercased())\(answer.lowercased())"
        let hashed = SHA256.hash(data: input.data(using: .utf8)!)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
