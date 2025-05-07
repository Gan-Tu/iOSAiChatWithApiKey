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

let availableModels: [ModelConfig] = [
    // xAI
    ModelConfig(provider: .xai, modelName: "grok-3-latest", displayName: "Grok 3"),
    ModelConfig(provider: .xai, modelName: "grok-3-mini-latest", displayName: "Grok 3 Mini (medium)", xAIReasoningEffort: "medium"), // Add reasoning parameter
    
    // OpenAI
    ModelConfig(provider: .openai, modelName: "gpt-4.1-mini", displayName: "GPT-4.1 Mini"),
    ModelConfig(provider: .openai, modelName: "gpt-4.1", displayName: "GPT-4.1"),
    ModelConfig(provider: .openai, modelName: "o4-mini", displayName: "o4 Mini (medium)", openAIReasoningEffort: "medium"), // Add reasoning parameter
    
    // Google Gemini
    ModelConfig(provider: .gemini, modelName: "gemini-2.5-flash-preview-04-17", displayName: "Gemini 2.5 Flash"),
    ModelConfig(provider: .gemini, modelName: "gemini-2.5-pro-preview-05-06", displayName: "Gemini 2.5 Pro")
]
