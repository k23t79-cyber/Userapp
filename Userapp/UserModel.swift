//
//  UserModel.swift
//  Userapp
//

import Foundation
import RealmSwift

class UserModel: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var email: String = ""
    @Persisted var name: String = ""
    @Persisted var method: String = ""   // login method (google/apple/email)
    @Persisted var signedInAt: Date = Date()
}
