//
//  ModelConfig.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

struct ModelConfig: Identifiable, Codable, Equatable, Hashable { // Add Codable, Hashable
    var id = UUID() // SwiftUI identifiable, also good for uniqueness
    var provider: Provider
    var modelName: String // This is the actual model ID used in API calls
    var displayName: String
    var priority: Int = 10
    var openAIReasoningEffort: String?
    var xAIReasoningEffort: String?
    var isCustom: Bool = false // Flag to distinguish custom models

    var requiresReasoningParameter: Bool {
        openAIReasoningEffort != nil || xAIReasoningEffort != nil
    }

    // Initializer for creating new models
    init(id: UUID = UUID(), provider: Provider, modelName: String, displayName: String, priority: Int = 10,
         openAIReasoningEffort: String? = nil, xAIReasoningEffort: String? = nil, isCustom: Bool = false) {
        self.id = id
        self.provider = provider
        self.modelName = modelName
        self.displayName = displayName
        self.priority = priority
        self.openAIReasoningEffort = openAIReasoningEffort
        self.xAIReasoningEffort = xAIReasoningEffort
        self.isCustom = isCustom
    }

    static let builtInModels: [ModelConfig] = [
        ModelConfig(provider: .openai, modelName: "gpt-6.1-sol", displayName: "GPT-6.1 Sol", priority: 1, openAIReasoningEffort: "medium"),
        ModelConfig(provider: .openai, modelName: "gpt-6-astra", displayName: "GPT-6 Astra", priority: 2, openAIReasoningEffort: "medium"),
        ModelConfig(provider: .openai, modelName: "gpt-6-luna", displayName: "GPT-6 Luna", priority: 3, openAIReasoningEffort: "none"),
        ModelConfig(provider: .xai, modelName: "grok-4.7", displayName: "Grok 4.7", priority: 1, xAIReasoningEffort: "medium"),
        ModelConfig(provider: .xai, modelName: "grok-4.3", displayName: "Grok 4.3", priority: 2, xAIReasoningEffort: "none"),
        ModelConfig(provider: .gemini, modelName: "gemini-3.8-flash", displayName: "Gemini 3.8 Flash", priority: 1),
        ModelConfig(provider: .gemini, modelName: "gemini-3.5-flash-lite", displayName: "Gemini 3.5 Flash-Lite", priority: 2),
        ModelConfig(provider: .gemini, modelName: "gemini-3.1-pro-preview", displayName: "Gemini 3.1 Pro (Preview)", priority: 3)
    ]

    // For Equatable and Hashable, we might only care about a subset of properties
    // if we consider two models the same if their core API identifiers match.
    // For now, default synthesis for Equatable and Hashable based on all properties is fine.
    // If you need more specific equality (e.g., for preventing duplicates based on modelName + provider):
    // static func == (lhs: ModelConfig, rhs: ModelConfig) -> Bool {
    //     return lhs.provider == rhs.provider && lhs.modelName == rhs.modelName
    // }
    // func hash(into hasher: inout Hasher) {
    //     hasher.combine(provider)
    //     hasher.combine(modelName)
    // }
}

// Provider also needs to be Codable for ModelConfig to be Codable
extension Provider: Codable {}
