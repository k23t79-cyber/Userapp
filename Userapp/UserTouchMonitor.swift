//
//  UserTouchMonitor.swift
//  Userapp
//
//  Created by Ri on 7/29/25.
//


import Foundation

class UserTouchMonitor {
    static var shared = UserTouchMonitor()
    private(set) var isUserInteracting: Bool = false

    func registerInteraction() {
        isUserInteracting = true
    }

    func reset() {
        isUserInteracting = false
    }
}
