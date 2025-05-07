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
    var openAIReasoningEffort: String?
    var xAIReasoningEffort: String?
    var isCustom: Bool = false // Flag to distinguish custom models

    var requiresReasoningParameter: Bool {
        openAIReasoningEffort != nil || xAIReasoningEffort != nil
    }

    // Initializer for creating new models
    init(id: UUID = UUID(), provider: Provider, modelName: String, displayName: String,
         openAIReasoningEffort: String? = nil, xAIReasoningEffort: String? = nil, isCustom: Bool = false) {
        self.id = id
        self.provider = provider
        self.modelName = modelName
        self.displayName = displayName
        self.openAIReasoningEffort = openAIReasoningEffort
        self.xAIReasoningEffort = xAIReasoningEffort
        self.isCustom = isCustom
    }

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
