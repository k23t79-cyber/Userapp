//
//  LocationUpdateDelegate.swift
//  Userapp
//

import Foundation

protocol LocationUpdateDelegate: AnyObject {
    /// Called when location is updated successfully
    func didUpdateLocation(latitude: Double, longitude: Double)

    /// Called when there’s an error fetching location
    func didFailWithError(_ error: Error)
}
