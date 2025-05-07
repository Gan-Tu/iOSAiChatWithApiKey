//
//  AddEditCustomModelView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct AddEditCustomModelView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChatViewModel // To add the model

    // State for the form fields
    @State private var displayName: String = ""
    @State private var modelName: String = "" // API Model ID
    @State private var selectedProvider: Provider = .openai // Default provider
    @State private var isOpenAIReasoning: Bool = false
    @State private var isXAIReasoning: Bool = false

    // To determine which reasoning effort to show
    private var showOpenAIReasoningToggle: Bool { selectedProvider == .openai }
    private var showXAIReasoningToggle: Bool { selectedProvider == .xai }


    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Details")) {
                    TextField("Display Name (e.g., My Custom GPT)", text: $displayName)
                    TextField("Model ID (from API provider)", text: $modelName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.name).tag(provider)
                        }
                    }
                }

                // Conditional reasoning toggles based on provider
                // Only show OpenAI reasoning if OpenAI provider selected, etc.
                // This logic might need refinement if a model can have both, or based on other API specs.
                Section(header: Text("Reasoning (Optional)")) {
                    if showOpenAIReasoningToggle {
                        Toggle("OpenAI Reasoning Effort (Medium)", isOn: $isOpenAIReasoning)
                    }
                    if showXAIReasoningToggle {
                        Toggle("xAI Reasoning Effort (Medium)", isOn: $isXAIReasoning)
                    }
                    if !showOpenAIReasoningToggle && !showXAIReasoningToggle {
                        Text("Reasoning effort not applicable for \(selectedProvider.name) or not yet configurable here.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }


                Button("Add Custom Model") {
                    saveCustomModel()
                }
                .disabled(displayName.isEmpty || modelName.isEmpty)
            }
            .navigationTitle("Add Custom Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveCustomModel() {
        // Construct the ModelConfig
        let newModel = ModelConfig(
            provider: selectedProvider,
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            openAIReasoningEffort: isOpenAIReasoning && selectedProvider == .openai ? "medium" : nil,
            xAIReasoningEffort: isXAIReasoning && selectedProvider == .xai ? "medium" : nil,
            isCustom: true
        )
        viewModel.addCustomModel(newModel)
        dismiss()
    }
}

struct AddEditCustomModelView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditCustomModelView(viewModel: ChatViewModel())
    }
}
