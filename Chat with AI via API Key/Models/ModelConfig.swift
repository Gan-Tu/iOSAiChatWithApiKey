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
    let openAIReasoningEffort: String? // Specific for OpenAI models like o4-mini
    let xAIReasoningEffort: String? // Specific for xAI mini

    var requiresReasoningParameter: Bool {
        openAIReasoningEffort != nil || xAIReasoningEffort != nil
    }

    init(provider: Provider, modelName: String, displayName: String, openAIReasoningEffort: String? = nil, xAIReasoningEffort: String? = nil) {
        self.provider = provider
        self.modelName = modelName
        self.displayName = displayName
        self.openAIReasoningEffort = openAIReasoningEffort
        self.xAIReasoningEffort = xAIReasoningEffort
    }
}
