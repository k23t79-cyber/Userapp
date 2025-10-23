//
//  QuestionsResponse.swift
//  Userapp
//

import Foundation
struct QuestionTemplate: Codable {
    let id: String
    let question: String
    let category: String
}


struct QuestionsResponse: Codable {
    let encryption_method: String
    let instructions: String
    let message: String
    let success: Bool
    let templates: [QuestionTemplate]
    let total_questions: Int
}
