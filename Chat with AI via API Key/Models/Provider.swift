//
//  Provider.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

enum Provider: String, Identifiable, CaseIterable {
    case xai
    case openai
    case gemini

    var id: String { self.rawValue }

    var name: String {
        switch self {
        case .openai: return "OpenAI"
        case .xai: return "xAI"
        case .gemini: return "Google"
        }
    }

    var apiKeyKeychainKey: String {
        switch self {
        case .openai: return "openai_api_key"
        case .xai: return "xai_api_key"
        case .gemini: return "gemini_api_key"
        }
    }
    
    var priority: Int {
        switch self {
        case .openai: return 1
        case .xai: return 2
        case .gemini: return 3
        }
    }
}
