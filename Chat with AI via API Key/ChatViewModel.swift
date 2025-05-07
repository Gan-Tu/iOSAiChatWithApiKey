//
//  ChatViewModel.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//
import SwiftUI
import Combine

class ChatViewModel: ObservableObject {
    private let selectedModelKey = "SelectedModelKey"
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var selectedModel: ModelConfig
    @Published var isLoading: Bool = false // Still useful to disable input/send button
    @Published var showModelSelectionSheet = false
    @Published var showAPIKeyConfigSheet = false
    @Published var showExpandedInputSheet = false // State for the expanded input sheet
    @Published var showAddCustomModelSheet = false // For presenting the add/edit view
    
    @Published var allAvailableModels: [ModelConfig] = [] // Combined list
    private var defaultModels: [ModelConfig] = [ // Hardcoded default models
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
    @Published var customModels: [ModelConfig] = [] {
        didSet {
            saveCustomModels()
            updateAllAvailableModels() // Update combined list when custom models change
        }
    }

    private let keychainService = KeychainService()
    
    // UserDefaults keys
    private let lastSelectedModelProviderKey = "lastSelectedModelProviderKey"
    private let lastSelectedModelNameKey = "lastSelectedModelNameKey"
    private let customModelsKey = "customModelsKey_v2" // Use a new key if format changes

    private var currentStreamingTask: URLSessionDataTask?
    private var currentAssistantMessageId: UUID? // To track the loading/streaming assistant message

    init() {
        // 1. Initialize selectedModel with a guaranteed default value first.
        //    Make sure defaultModels is not empty, or handle that case.
        if let firstDefault = defaultModels.first {
            self.selectedModel = firstDefault
        } else {
            // This case should ideally not happen if defaultModels is always populated.
            // Provide an absolute fallback if defaultModels could somehow be empty.
            self.selectedModel = ModelConfig(provider: .openai, modelName: "gpt-4.1", displayName: "Fallback Default GPT-4.1")
            print("CRITICAL WARNING: defaultModels array was empty during init. Using absolute fallback.")
        }

        // 2. Now that all stored properties are initialized, we can call instance methods.
        loadCustomModels()          // Loads into self.customModels, triggers didSet
        updateAllAvailableModels()  // Populates self.allAvailableModels

        // 3. Attempt to load and set the *actual* last selected model from UserDefaults.
        //    This will override the preliminary default if a saved model is found.
        if let lastModelProviderRaw = UserDefaults.standard.string(forKey: lastSelectedModelProviderKey),
           let lastModelName = UserDefaults.standard.string(forKey: lastSelectedModelNameKey),
           let lastProvider = Provider(rawValue: lastModelProviderRaw),
           let foundModelInAll = allAvailableModels.first(where: { $0.provider == lastProvider && $0.modelName == lastModelName }) {
            self.selectedModel = foundModelInAll // Override with the loaded model
            print("DEBUG: Loaded last selected model from UserDefaults: \(foundModelInAll.displayName)")
        } else {
            // If no saved model, or saved model is no longer in allAvailableModels,
            // selectedModel remains the preliminary default set in step 1.
            // We might want to ensure it's the first of the *combined* list if custom models were loaded.
            if let firstOverall = allAvailableModels.first {
                 self.selectedModel = firstOverall
            }
            print("DEBUG: No valid last selected model found in UserDefaults or it's no longer available. Using first available model: \(self.selectedModel.displayName)")
        }

        // 4. Finally, check API keys for the now definitively set selectedModel.
        checkAPIKeys()
    }
    
    private func updateAllAvailableModels() {
        // Combine default and custom models.
        // Sort them for consistent display order.
        allAvailableModels = (defaultModels + customModels).sorted {
            if $0.provider.name == $1.provider.name {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.provider.name.localizedCaseInsensitiveCompare($1.provider.name) == .orderedAscending
        }
    }

    // MARK: - Custom Model Persistence
    private func loadCustomModels() {
        if let savedData = UserDefaults.standard.data(forKey: customModelsKey) {
            do {
                // This will trigger the didSet for customModels if successful
                self.customModels = try JSONDecoder().decode([ModelConfig].self, from: savedData)
                print("DEBUG: Loaded \(self.customModels.count) custom models.")
            } catch {
                print("Error decoding custom models: \(error.localizedDescription)")
                self.customModels = [] // Ensure it's an empty array on failure
            }
        } else {
            self.customModels = [] // No saved custom models
        }
    }

    private func saveCustomModels() {
        do {
            let data = try JSONEncoder().encode(customModels)
            UserDefaults.standard.set(data, forKey: customModelsKey)
            print("DEBUG: Saved \(customModels.count) custom models.")
        } catch {
            print("Error encoding custom models: \(error.localizedDescription)")
        }
    }

    func addCustomModel(_ model: ModelConfig) {
        var newModel = model
        newModel.isCustom = true
        if !customModels.contains(where: { $0.provider == newModel.provider && $0.modelName == newModel.modelName }) {
            customModels.append(newModel)
        } else {
            print("DEBUG: Custom model with provider \(newModel.provider.name) and name \(newModel.modelName) already exists.")
        }
    }
    
    func deleteCustomModel(model: ModelConfig) {
        guard model.isCustom else { return }
        customModels.removeAll { $0.id == model.id }
    }
    
    // MARK: - Model Persistence (Last Selected)
    private func saveSelectedModelToUserDefaults(_ model: ModelConfig) {
        UserDefaults.standard.set(model.provider.rawValue, forKey: lastSelectedModelProviderKey)
        UserDefaults.standard.set(model.modelName, forKey: lastSelectedModelNameKey)
        print("DEBUG: Saved selected model to UserDefaults: \(model.displayName)")
    }

    // MARK: - API Key Management (No changes needed here from previous version)

    func getAPIKey(for provider: Provider) -> String? {
        keychainService.load(key: provider.apiKeyKeychainKey)
    }

    func saveAPIKey(_ apiKey: String, for provider: Provider) {
        let status = keychainService.save(key: provider.apiKeyKeychainKey, value: apiKey)
        if status != errSecSuccess {
            // print("Failed to save API key for \(provider.name): \(status)")
        } else {
             // print("Successfully saved API key for \(provider.name)")
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
        guard !isLoading else { return } // Prevents multiple simultaneous requests

        let userMessageContent = inputText
        messages.append(Message(role: .user, content: userMessageContent))
        inputText = ""
        isLoading = true // Set general loading state

        // Create and add the placeholder message
        let placeholderId = UUID()
        currentAssistantMessageId = placeholderId // Track this ID
        let placeholderMessage = Message(id: placeholderId, role: .assistant, content: "", isStreaming: false, isLoadingPlaceholder: true)
        messages.append(placeholderMessage)
        // print("DEBUG: Added placeholder with ID: \(placeholderId)")


        guard let apiKey = getAPIKey(for: selectedModel.provider), !apiKey.isEmpty else {
            handleCompletion(.failure(.apiKeyMissing))
            return
        }

        let service: AIProviderService
        switch selectedModel.provider {
        case .openai: service = OpenAIService()
        case .xai: service = XAIService()
        case .gemini: service = GeminiService()
        }

        // Prepare messages for API (exclude any active placeholder from history sent to API)
        let messagesForAPI = messages.filter { msg in
            !(msg.id == currentAssistantMessageId && msg.isLoadingPlaceholder) && msg.role != .error
        }

        currentStreamingTask = service.streamChatCompletion(
            model: selectedModel,
            messages: messagesForAPI,
            apiKey: apiKey,
            onToken: { [weak self] token in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    guard let assistantMsgId = self.currentAssistantMessageId,
                          let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) else {
                        // print("DEBUG OnToken: No current assistant message found or ID mismatch. Current ID: \(String(describing: self.currentAssistantMessageId))")
                        // Remove any existing loading placeholder to avoid duplication
                        self.messages.removeAll { $0.isLoadingPlaceholder }
                        // Fallback: if message is somehow lost, create a new one if token is not empty
                        if !token.isEmpty {
                            // Remove any lingering placeholder to avoid showing old loading messages
                            self.messages.removeAll { $0.isLoadingPlaceholder }

                            let newMessage = Message(role: .assistant, content: token, isStreaming: true)
                            self.messages.append(newMessage)
                            self.currentAssistantMessageId = newMessage.id // Start tracking new message
                        }
                        return
                    }

                    // We found the message at 'index'.
                    var messageToUpdate = self.messages[index] // Get a copy

                    if messageToUpdate.isLoadingPlaceholder {
                        // This is the first token for this message
                        // print("DEBUG OnToken: First token for placeholder ID \(assistantMsgId). Token: '\(token)'. Clearing placeholder.")
                        messageToUpdate.isLoadingPlaceholder = false
                        messageToUpdate.isStreaming = true
                        messageToUpdate.content = token // Set initial content
                    } else if messageToUpdate.isStreaming {
                        // Subsequent token
                        // print("DEBUG OnToken: Subsequent token for streaming ID \(assistantMsgId). Token: '\(token)'")
                        messageToUpdate.content += token
                    } else {
                        // Message was found but isn't a placeholder and isn't streaming
                        // This state shouldn't ideally occur if logic is correct
                        // print("DEBUG OnToken: Token for non-streaming/non-placeholder ID \(assistantMsgId). Content: '\(messageToUpdate.content)', Token: '\(token)'")
                        if messageToUpdate.role == .assistant { // Only append if it's an assistant message
                            messageToUpdate.content += token
                            // messageToUpdate.isStreaming = true; // Optionally re-mark as streaming
                        }
                    }
                    self.messages[index] = messageToUpdate // Assign the modified struct back to trigger UI update
                }
            },
            onComplete: { [weak self] result in
                self?.handleCompletion(result)
            }
        )
    }

    func handleCompletion(_ result: Result<Void, AIProviderServiceError>) {
        DispatchQueue.main.async {
            self.isLoading = false // Reset general loading state

            guard let assistantMsgId = self.currentAssistantMessageId,
                  let index = self.messages.firstIndex(where: { $0.id == assistantMsgId }) else {
                // print("DEBUG HandleCompletion: No current assistant message ID or message not found at completion. Current ID: \(String(describing: self.currentAssistantMessageId))")
                self.currentAssistantMessageId = nil // Ensure it's cleared
                self.currentStreamingTask = nil
                if case .failure(let error) = result {
                    self.messages.append(Message(role: .error, content: error.localizedDescription))
                    if case .apiKeyMissing = error { self.showAPIKeyConfigSheet = true }
                }
                return
            }

            // We found the message
            var completedMessage = self.messages[index]
            completedMessage.isStreaming = false // Always mark as not streaming on completion

            // If it was a placeholder AND it's still empty (e.g., error before any token arrived)
            if completedMessage.isLoadingPlaceholder && completedMessage.content.isEmpty {
                // print("DEBUG HandleCompletion: Removing empty placeholder ID \(assistantMsgId) due to empty content on completion.")
                self.messages.remove(at: index)
            }
            // If it was a normal streaming message (not placeholder) but ended up with empty content
            else if !completedMessage.isLoadingPlaceholder && completedMessage.content.isEmpty {
                // print("DEBUG HandleCompletion: Removing empty streaming message ID \(assistantMsgId) due to empty content on completion.")
                self.messages.remove(at: index)
            }
            // Otherwise, update the message in the array (its isStreaming flag changed)
            else {
                // print("DEBUG HandleCompletion: Finalizing message ID \(assistantMsgId). Placeholder: \(completedMessage.isLoadingPlaceholder), Content: '\(completedMessage.content)'")
                self.messages[index] = completedMessage
            }

            self.currentAssistantMessageId = nil // Clear the tracked ID
            self.currentStreamingTask = nil

            if case .failure(let error) = result {
                // Check if an error message for this specific failure isn't already shown
                // (e.g., if the assistant message was removed, we definitely need to add the error).
                // For simplicity, we'll add it. Can be refined if duplicate errors appear.
                // print("DEBUG HandleCompletion: API Error: \(error.localizedDescription)")
                self.messages.append(Message(role: .error, content: error.localizedDescription))
                if case .apiKeyMissing = error {
                    self.showAPIKeyConfigSheet = true
                }
            }
        }
    }

    func cancelStreaming() {
        // print("DEBUG: cancelStreaming called. Task: \(String(describing: currentStreamingTask))")
        // The task's completion handler (didCompleteWithError with URLError.cancelled)
        // will call handleCompletion, which resets states.
        currentStreamingTask?.cancel()
        // We can also pre-emptively update UI if needed, but handleCompletion should be robust.
        // If handleCompletion might not be called immediately or reliably on cancel for some reason,
        // then manually cleaning up the placeholder here is a fallback.
        if let assistantMsgId = self.currentAssistantMessageId,
           let index = self.messages.firstIndex(where: { $0.id == assistantMsgId && $0.isLoadingPlaceholder }) {
            DispatchQueue.main.async { // Ensure UI updates on main thread
                // print("DEBUG cancelStreaming: Proactively removing placeholder ID \(assistantMsgId) on cancel.")
                self.messages.remove(at: index)
                self.currentAssistantMessageId = nil
                self.isLoading = false // Also reset general loading
            }
        } else {
            // If it wasn't a placeholder, handleCompletion will manage it.
            DispatchQueue.main.async { self.isLoading = false }
        }
    }

    // MARK: - Model Selection, New Chat, Expanded Input methods
    func selectModel(_ model: ModelConfig) {
        selectedModel = model
        UserDefaults.standard.set(model.modelName, forKey: selectedModelKey)
        showModelSelectionSheet = false
        startNewChat()
    }

    func startNewChat() {
        // print("DEBUG: startNewChat called.")
        cancelStreaming() // Important to cancel ongoing stream
        messages = []
        inputText = ""
        currentAssistantMessageId = nil // Critical reset
        isLoading = false             // Critical reset
        checkAPIKeys()
    }

    func expandInputArea() { showExpandedInputSheet = true }
    func dismissExpandedInput() { showExpandedInputSheet = false }
}
