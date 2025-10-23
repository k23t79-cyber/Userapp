import UIKit

extension UIDevice {
    var deviceIdentifier: String {
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}
