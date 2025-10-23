import Foundation
import CoreLocation

struct TrustSignal {
    let timestamp: Date
    let location: CLLocation?
    let isVPNEnabled: Bool
    let isSilentMode: Bool
    let typingSpeed: Double
}
