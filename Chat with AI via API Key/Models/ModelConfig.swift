//
//  ModelConfig.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

struct ModelConfig: Identifiable, Equatable {
    let id = UUID() // Using UUID as a unique ID for SwiftUI Lists
    let provider: Provider
    let modelName: String
    let displayName: String
    let requiresReasoningEffort: Bool // Specific for xAI mini
}
