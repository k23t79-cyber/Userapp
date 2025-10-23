import UIKit
import Supabase

class OTPVerificationViewController: UIViewController {
    
    var email: String = "" // This should be set from the previous screen
    
    let otpTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter OTP"
        textField.borderStyle = .roundedRect
        return textField
    }()
    
    let verifyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Verify OTP", for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    func setupUI() {
        view.addSubview(otpTextField)
        view.addSubview(verifyButton)
        
        otpTextField.translatesAutoresizingMaskIntoConstraints = false
        verifyButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            otpTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            otpTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            otpTextField.widthAnchor.constraint(equalToConstant: 200),
            
            verifyButton.topAnchor.constraint(equalTo: otpTextField.bottomAnchor, constant: 20),
            verifyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        verifyButton.addTarget(self, action: #selector(verifyOTP), for: .touchUpInside)
    }
    
    @objc func verifyOTP() {
        guard let token = otpTextField.text, !token.isEmpty else {
            print("❌ Please enter the OTP")
            return
        }
        
        print("🔍 Verifying OTP for email: \(email) with token: \(token)")
        
        SupabaseManager.shared.verifyOTP(email: email, token: token, type: .signup) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let session):
                    print("Verification successful: \(session)")
                    // Navigate to the next screen here
                case .failure(let error):
                    print("Verification failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
