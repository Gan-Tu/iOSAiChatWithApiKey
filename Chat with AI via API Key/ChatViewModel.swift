//
//  ChatViewModel.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var selectedModel: ModelConfig
    @Published var isLoading: Bool = false // To disable input while streaming
    @Published var showModelSelectionSheet = false
    @Published var showAPIKeyConfigSheet = false // This state is already here!

    private let keychainService = KeychainService()

    // Hardcoded list of supported models
    let availableModels: [ModelConfig] = [
        // OpenAI
        ModelConfig(provider: .openai, modelName: "gpt-4.1-mini", displayName: "GPT-4.1 Mini", requiresReasoningEffort: false),
        ModelConfig(provider: .openai, modelName: "gpt-4.1", displayName: "GPT-4.1", requiresReasoningEffort: false),
        ModelConfig(provider: .openai, modelName: "gpt-4o-mini", displayName: "GPT-4o Mini", requiresReasoningEffort: false),
        ModelConfig(provider: .openai, modelName: "o4-mini", displayName: "o4 Mini", requiresReasoningEffort: false),

        // xAI
        ModelConfig(provider: .xai, modelName: "grok-3-latest", displayName: "Grok 3 Latest", requiresReasoningEffort: false),
        ModelConfig(provider: .xai, modelName: "grok-3-mini-latest", displayName: "Grok 3 Mini Latest", requiresReasoningEffort: true),

        // Google Gemini
        ModelConfig(provider: .gemini, modelName: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash", requiresReasoningEffort: false),
        ModelConfig(provider: .gemini, modelName: "gemini-2.5-flash-preview-04-17", displayName: "Gemini 2.5 Flash Preview", requiresReasoningEffort: false),
        ModelConfig(provider: .gemini, modelName: "gemini-2.5-pro-preview-05-06", displayName: "Gemini 2.5 Pro Preview", requiresReasoningEffort: false)
    ]

    private var currentStreamingTask: URLSessionDataTask?

    init() {
        self.selectedModel = availableModels.first!
        checkAPIKeys() // Initial check on app launch
    }

    // MARK: - API Key Management

    func getAPIKey(for provider: Provider) -> String? {
        keychainService.load(key: provider.apiKeyKeychainKey)
    }

    func saveAPIKey(_ apiKey: String, for provider: Provider) {
        let status = keychainService.save(key: provider.apiKeyKeychainKey, value: apiKey)
        if status != errSecSuccess {
            print("Failed to save API key for \(provider.name): \(status)")
        } else {
             print("Successfully saved API key for \(provider.name)")
             // After saving, re-check if the *currently selected* model's key is now present
             checkAPIKeys()
        }
    }

    func checkAPIKeys() {
        // Check if the key for the *currently selected* model's provider exists
        let apiKey = getAPIKey(for: selectedModel.provider)
        if apiKey == nil || apiKey?.isEmpty == true {
            showAPIKeyConfigSheet = true
        } else {
             showAPIKeyConfigSheet = false // Hide if key is now present
        }
    }

    // New method to explicitly request showing the config sheet
    func requestAPIKeyConfiguration() {
        showAPIKeyConfigSheet = true
    }

    // MARK: - Chat Actions

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading else { return }

        let userMessageContent = inputText
        messages.append(Message(role: .user, content: userMessageContent))
        inputText = ""
        isLoading = true

        messages.append(Message(role: .assistant, content: "", isStreaming: true))

        guard let apiKey = getAPIKey(for: selectedModel.provider), !apiKey.isEmpty else {
            handleCompletion(.failure(.apiKeyMissing))
            return // Return nil as no task was started
        }

        let service: AIProviderService
        switch selectedModel.provider {
        case .openai:
            service = OpenAIService()
        case .xai:
            service = XAIService()
        case .gemini:
            service = GeminiService()
        }

        currentStreamingTask = service.streamChatCompletion(
            model: selectedModel,
            messages: messages.filter { $0.role != .error },
            apiKey: apiKey,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    if let index = self?.messages.lastIndex(where: { $0.isStreaming }) {
                        self?.messages[index].content += token
                    }
                }
            },
            onComplete: { [weak self] result in
                self?.handleCompletion(result)
            }
        )
        // Returning the task here is useful for external cancellation, but the handleCompletion
        // takes care of ending the loading state and clearing the task reference internally.
        // For the ViewModel's direct control, storing it in currentStreamingTask is sufficient.
    }

    func handleCompletion(_ result: Result<Void, AIProviderServiceError>) {
        DispatchQueue.main.async {
            self.isLoading = false

            if let index = self.messages.lastIndex(where: { $0.isStreaming }) {
                self.messages[index].isStreaming = false
            }

            switch result {
            case .success:
                break // Handled by token updates

            case .failure(let error):
                print("API Error: \(error.localizedDescription)")
                // Check if the last message is the empty streaming one before adding error
                if let lastMsg = self.messages.last, lastMsg.role == .assistant && lastMsg.content.isEmpty {
                     // Replace the empty streaming message with the error message?
                     // Or add a new error message? Adding a new one seems clearer.
                     self.messages.append(Message(role: .error, content: error.localizedDescription))
                 } else {
                      // Add error message after any received content
                      self.messages.append(Message(role: .error, content: error.localizedDescription))
                 }


                if case .apiKeyMissing = error {
                    self.showAPIKeyConfigSheet = true // Explicitly show config if key is missing
                }
            }
            self.currentStreamingTask = nil
        }
    }

    func cancelStreaming() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        isLoading = false
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].isStreaming = false
            if messages[index].content.isEmpty {
                 messages.remove(at: index) // Remove empty placeholder if nothing streamed
             } else {
                 messages[index].content += "\n\n(Cancelled)" // Indicate cancellation
             }
        }
    }

    // MARK: - Model Selection

    func selectModel(_ model: ModelConfig) {
        selectedModel = model
        // showModelSelectionSheet = false // This dismissal will be handled in the View
        checkAPIKeys() // Check key for the newly selected model
    }
}

