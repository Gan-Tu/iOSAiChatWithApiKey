//
//  ModelSelectionView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct ModelSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChatViewModel

    // Group models by provider and sort them
    private var groupedAndSortedModels: [Provider: [ModelConfig]] {
        Dictionary(grouping: viewModel.allAvailableModels, by: { $0.provider })
            .mapValues { modelsInGroup in
                modelsInGroup.sorted {
                    if $0.priority != $1.priority {
                        return $0.priority < $1.priority
                    } else {
                        return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                }
            }
    }

    // Get sorted list of providers that have models
    private var sortedProviders: [Provider] {
        groupedAndSortedModels.keys.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            } else {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    var body: some View {
            NavigationView {
                List {
                    ForEach(sortedProviders, id: \.self) { provider in
                        Section(header: Text(provider.name)) {
                            ForEach(groupedAndSortedModels[provider] ?? []) { model in
                                modelRow(for: model) // Use the extracted modelRow view
                            }
                        }
                    }
                }
                .navigationTitle("Select Model")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            viewModel.requestAPIKeyConfiguration()
                            dismiss()
                        } label: {
                            Label("API Keys", systemImage: "key.horizontal")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button {
                                viewModel.showAddCustomModelSheet = true
                                dismiss()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }

        // Extracted ViewBuilder for the model row
        @ViewBuilder
        private func modelRow(for model: ModelConfig) -> some View {
            Button {
                viewModel.selectModel(model)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { // Added spacing
                        Text(model.displayName)
                            .foregroundColor(.primary)
                        Text("ID: \(model.modelName)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // HStack for labels (Custom, Reasoning)
                        HStack(spacing: 6) {
                            if model.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundColor(.orange)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            if model.requiresReasoningParameter {
                                Text("reasoning")
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundColor(.green)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            // FIX: Display Reasoning Effort Label
                            if let openAIEffort = model.openAIReasoningEffort {
                                reasoningLabel(text: "\(openAIEffort)")
                            } else if let xAIEffort = model.xAIReasoningEffort {
                                reasoningLabel(text: "\(xAIEffort)")
                            }
                        }
                    }
                    Spacer()
                    if model.id == viewModel.selectedModel.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 4) // Add some vertical padding to the button content for better touch target and spacing
            }
            .contextMenu { // Context menu for deleting custom models
                if model.isCustom {
                    Button(role: .destructive) {
                        viewModel.deleteCustomModel(model: model)
                    } label: {
                        Label("Delete Custom Model", systemImage: "trash")
                    }
                }
            }
        }

        // Helper view for the reasoning label for consistent styling
        @ViewBuilder
        private func reasoningLabel(text: String) -> some View {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .foregroundColor(.purple) // Different color for reasoning
                .background(Color.purple.opacity(0.2))
                .cornerRadius(4)
        }
}

struct ModelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample ViewModel for preview
        let previewViewModel = ChatViewModel()
        return ModelSelectionView(viewModel: previewViewModel)
    }
}
