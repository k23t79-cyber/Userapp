//
//  LocationManager.swift
//  Userapp
//

import Foundation
import CoreLocation



class LocationManager: NSObject, CLLocationManagerDelegate {
    
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    weak var delegate: LocationUpdateDelegate?
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // ✅ Request user permission
    func requestLocationAccess() {
        manager.requestWhenInUseAuthorization()
    }
    
    // ✅ Start continuous updates
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    // ✅ Stop updates
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    // ✅ One-time current location fetch
    func getCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        manager.requestLocation()
        self.completionHandler = completion
    }
    
    // MARK: - CLLocationManagerDelegate
    
    private var completionHandler: ((CLLocation?) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            completionHandler?(nil)
            return
        }
        
        // Notify delegate
        delegate?.didUpdateLocation(latitude: location.coordinate.latitude,
                                    longitude: location.coordinate.longitude)
        
        // Return one-time location if requested
        completionHandler?(location)
        completionHandler = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ LocationManager error: \(error.localizedDescription)")
        delegate?.didFailWithError(error)
        completionHandler?(nil)
        completionHandler = nil
    }
}
