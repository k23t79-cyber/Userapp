//
//  ViewController.swift
//  Userapp
//

import UIKit
import RealmSwift
import CoreLocation

class ViewController: UIViewController, LocationUpdateDelegate {
    func didFailWithError(_ error: any Error) {
        
    }

    private let locationLabel = UILabel()
    private let trustStatusLabel = UILabel()
    private var currentLocation: CLLocation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        print("✅ ViewController Loaded")

        setupUI()
        testRealmWrite()

        // Start location updates
        LocationManager.shared.delegate = self
        LocationManager.shared.requestLocationAccess()
        LocationManager.shared.startUpdatingLocation()

        print("📡 Location tracking started.")
    }
    
    // MARK: - UI Setup
    func setupUI() {
        locationLabel.translatesAutoresizingMaskIntoConstraints = false
        trustStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        locationLabel.font = UIFont.systemFont(ofSize: 16)
        trustStatusLabel.font = UIFont.boldSystemFont(ofSize: 18)

        locationLabel.textColor = .black
        trustStatusLabel.textColor = .systemBlue

        locationLabel.text = "Waiting for location..."
        trustStatusLabel.text = "Trust status will appear here"

        view.addSubview(locationLabel)
        view.addSubview(trustStatusLabel)

        NSLayoutConstraint.activate([
            locationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            locationLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            trustStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trustStatusLabel.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 20)
        ])
    }

    // MARK: - LocationUpdateDelegate
    func didUpdateLocation(latitude: Double, longitude: Double) {
        print("📍 ViewController received location: \(latitude), \(longitude)")

        currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        locationLabel.text = "Lat: \(latitude), Lon: \(longitude)"

        guard let location = currentLocation else { return }

        // ✅ Evaluate Trust
        let isTrusted = TrustManager.shared.evaluateLocationTrust(currentLocation: location)
        trustStatusLabel.text = isTrusted ? "Trusted ✅" : "Untrusted ❌"

        // ✅ Save TrustSnapshot in Realm
        do {
            let realm = try Realm()

            let snapshot = TrustSnapshot()
            snapshot.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            snapshot.userId = "test-user"
            snapshot.timestamp = Date()
            snapshot.trustLevel = isTrusted ? 1 : 0   // Int version

            try realm.write {
                realm.add(snapshot)
            }
            print("💾 Saved TrustSnapshot at \(snapshot.timestamp)")

        } catch {
            print("❌ Error saving TrustSnapshot: \(error.localizedDescription)")
        }
    }

    func didFailWithLocationError(_ error: Error) {
        print("❌ Location Error: \(error.localizedDescription)")
        locationLabel.text = "❌ Failed to get location."
        trustStatusLabel.text = "Trust status unavailable."
    }
    // MARK: - Realm Test
    func testRealmWrite() {
        do {
            let realm = try Realm()
            let test = TrustSnapshot()
            test.trustLevel = 1
            try realm.write {
                realm.add(test)
            }
            print("✅ testRealmWrite(): Test TrustSnapshot added.")
            print("📂 Realm file location: \(String(describing: realm.configuration.fileURL))")

        } catch {
            print("❌ testRealmWrite(): Realm error - \(error)")
        }
    }
}
