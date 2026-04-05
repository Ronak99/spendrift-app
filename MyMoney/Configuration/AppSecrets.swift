//
//  AppSecrets.swift
//  MyMoney
//
//  Created by Cursor on 23/03/26.
//

import Foundation

enum AppSecrets {
    // Intentionally empty placeholder. User will provide later.
    static let openAIAPIKey = Bundle.main.infoDictionary?["OpenAIApiKey"] as? String ?? ""
}
