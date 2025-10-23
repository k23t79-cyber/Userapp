//
//  UserProfile.swift
//  Userapp
//
//  Created by Ri on 10/1/25.
//


import Foundation
import RealmSwift

class UserProfile: Object {
    @Persisted(primaryKey: true) var id: UUID = UUID()
    @Persisted var userId: String = ""
    @Persisted var name: String = ""
    @Persisted var email: String = ""
    @Persisted var phoneNumber: String = ""
    @Persisted var profileImagePath: String? = nil
    @Persisted var createdAt: Date = Date()
    @Persisted var updatedAt: Date = Date()
    @Persisted var version: Int = 1  // Track edit versions
    
    convenience init(userId: String, name: String, email: String, phoneNumber: String) {
        self.init()
        self.userId = userId
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
    }
}