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
    @Published var isLoading: Bool = false // Still useful to disable input/send button
    @Published var showModelSelectionSheet = false
    @Published var showAPIKeyConfigSheet = false
    @Published var showExpandedInputSheet = false // State for the expanded input sheet

    private let keychainService = KeychainService()

    // Hardcoded list of supported models - UPDATED
    let availableModels: [ModelConfig] = [
        // xAI
        ModelConfig(provider: .xai, modelName: "grok-3-latest", displayName: "Grok 3 Latest"),
        ModelConfig(provider: .xai, modelName: "grok-3-mini-latest", displayName: "Grok 3 Mini Latest", xAIReasoningEffort: "medium"), // Add reasoning parameter
        
        // OpenAI
        ModelConfig(provider: .openai, modelName: "gpt-4.1-mini", displayName: "GPT-4.1 Mini"),
        ModelConfig(provider: .openai, modelName: "gpt-4.1", displayName: "GPT-4.1"),
        ModelConfig(provider: .openai, modelName: "gpt-4o-mini", displayName: "GPT-4o Mini"), // Assuming no reasoning needed by default, adjust if required
        ModelConfig(provider: .openai, modelName: "o4-mini", displayName: "o4 Mini", openAIReasoningEffort: "medium"), // Add reasoning parameter
        
        // Google Gemini
        ModelConfig(provider: .gemini, modelName: "gemini-2.0-flash", displayName: "Gemini 2.0 Flash"),
        ModelConfig(provider: .gemini, modelName: "gemini-2.5-flash-preview-04-17", displayName: "Gemini 2.5 Flash Preview"),
        ModelConfig(provider: .gemini, modelName: "gemini-2.5-pro-preview-05-06", displayName: "Gemini 2.5 Pro Preview")
    ]

    private var currentStreamingTask: URLSessionDataTask?

    init() {
        self.selectedModel = availableModels.first!
        checkAPIKeys()
    }

    // MARK: - API Key Management (No changes needed here from previous version)

    func getAPIKey(for provider: Provider) -> String? {
        keychainService.load(key: provider.apiKeyKeychainKey)
    }

    func saveAPIKey(_ apiKey: String, for provider: Provider) {
        let status = keychainService.save(key: provider.apiKeyKeychainKey, value: apiKey)
        if status != errSecSuccess {
            print("Failed to save API key for \(provider.name): \(status)")
        } else {
             print("Successfully saved API key for \(provider.name)")
             checkAPIKeys()
        }
    }

    func checkAPIKeys() {
        let apiKey = getAPIKey(for: selectedModel.provider)
        if apiKey == nil || apiKey?.isEmpty == true {
            showAPIKeyConfigSheet = true
        } else {
             showAPIKeyConfigSheet = false
        }
    }

    func requestAPIKeyConfiguration() {
        showAPIKeyConfigSheet = true
    }

    // MARK: - Chat Actions - UPDATED

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isLoading else { return } // Prevent sending while another response is streaming

        let userMessageContent = inputText
        messages.append(Message(role: .user, content: userMessageContent))
        inputText = "" // Clear input immediately
        isLoading = true // Indicate loading state

        // FIX 5: DO NOT add an empty assistant message placeholder here.
        // The assistant message will be added when the *first* token arrives.

        guard let apiKey = getAPIKey(for: selectedModel.provider), !apiKey.isEmpty else {
            handleCompletion(.failure(.apiKeyMissing))
            return
        }

        // Select the appropriate service
        let service: AIProviderService
        switch selectedModel.provider {
        case .openai: service = OpenAIService()
        case .xai: service = XAIService()
        case .gemini: service = GeminiService()
        }

        // Keep track if the assistant message has been added for the current stream
        // This is slightly complex state. An alternative is to always append tokens
        // to the LAST message *if* it's an assistant message, otherwise create one.
        // Let's use the latter approach for simplicity.

        currentStreamingTask = service.streamChatCompletion(
            model: selectedModel,
            messages: messages.filter { $0.role != .error }, // Don't send error messages to API
            apiKey: apiKey,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // FIX 5: Add assistant message ONLY if it doesn't exist as the last message
                    if self.messages.last?.role != .assistant || !(self.messages.last?.isStreaming ?? false) {
                         // Add a new assistant message if the last one wasn't the streaming one
                         // (e.g., user sent another message quickly, or first token arrived)
                         self.messages.append(Message(role: .assistant, content: token, isStreaming: true))
                     } else {
                         // Append token to the existing streaming assistant message
                         if let index = self.messages.lastIndex(where: { $0.isStreaming }) {
                            self.messages[index].content += token
                         }
                     }
                }
            },
            onComplete: { [weak self] result in
                self?.handleCompletion(result)
            }
        )
    }

    func handleCompletion(_ result: Result<Void, AIProviderServiceError>) {
        DispatchQueue.main.async {
            self.isLoading = false // Stop loading indicator

            // Find the streaming message and mark it as done
            if let index = self.messages.lastIndex(where: { $0.isStreaming }) {
                 self.messages[index].isStreaming = false // Mark as not streaming
                 // If the message is still empty after completion (e.g., API failed before first token)
                 // remove it to avoid an empty bubble.
                 if self.messages[index].content.isEmpty {
                     self.messages.remove(at: index)
                 }
            }

            switch result {
            case .success:
                // Response finished successfully
                break // Handled by token updates and state changes above

            case .failure(let error):
                // Handle the error
                print("API Error: \(error.localizedDescription)")
                // Add an error message to the chat
                // Decide where to add the error: After the user message, or after the failed assistant message?
                // Adding it at the end is generally clearer.
                self.messages.append(Message(role: .error, content: error.localizedDescription))

                // If the error is API key missing, show config sheet
                if case .apiKeyMissing = error {
                    self.showAPIKeyConfigSheet = true
                }
            }
            self.currentStreamingTask = nil // Clear the task reference
        }
    }

    func cancelStreaming() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        isLoading = false

        // Update the last streaming message to indicate cancellation
        if let index = messages.lastIndex(where: { $0.isStreaming }) {
            messages[index].isStreaming = false
            if messages[index].content.isEmpty {
                 messages.remove(at: index) // Remove empty placeholder if nothing streamed
             } else {
                 messages[index].content += "\n\n(Cancelled)" // Indicate cancellation
             }
        }
    }

    // MARK: - Model Selection - UPDATED

    func selectModel(_ model: ModelConfig) {
        selectedModel = model
        showModelSelectionSheet = false // Dismiss the sheet

        // FIX 2: Clear chat history when switching models
        startNewChat() // This also checks API keys

        // checkAPIKeys() // startNewChat() does this now
    }

    // MARK: - New Chat Action - ADDED

    // FIX 3: Method to start a new chat
    func startNewChat() {
        // Cancel any ongoing streaming task
        cancelStreaming()
        // Clear all messages
        messages = []
        // Clear input text
        inputText = ""
        // Re-check API keys for the current model (useful if switching models triggered this)
        checkAPIKeys()
        print("Started new chat.") // Debugging
    }

    // MARK: - Expanded Input Action - ADDED

    // FIX 1: Method to request showing the expanded input sheet
    func expandInputArea() {
        showExpandedInputSheet = true
    }

    // Method to update input text from the expanded sheet (though binding handles it)
    // and dismiss the sheet
    func dismissExpandedInput() {
        showExpandedInputSheet = false
    }

}
