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
                // Iterate over sorted providers
                ForEach(sortedProviders, id: \.self) { provider in
                    Section(header: Text(provider.name)) {
                        // Iterate over models sorted within this provider group
                        ForEach(groupedAndSortedModels[provider] ?? []) { model in
                            modelRow(for: model)
                        }
                        // Only allow deletion for custom models.
                        // .onDelete needs to be on ForEach that directly maps to deletable items.
                        // This is more complex with sections. A common pattern is to have separate ForEach for custom.
                        // For simplicity here, we'll allow deletion via a context menu or detail view if needed,
                        // or the user can manage custom models from a dedicated settings screen.
                        // The current `deleteCustomModelItems` is geared towards a flat list of custom models.
                        // Let's adjust deletion to be more targeted if we keep this structure.
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
                            dismiss() // Dismiss this sheet to allow the new one to present
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

    @ViewBuilder
    private func modelRow(for model: ModelConfig) -> some View {
        Button {
            viewModel.selectModel(model) // Selects and starts new chat (if different)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.displayName)
                        .foregroundColor(.primary)
                    Text("ID: \(model.modelName)") // Provider name is in section header
                        .font(.caption)
                        .foregroundColor(.gray)
                    if model.isCustom {
                        Text("Custom")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Spacer()
                if model.id == viewModel.selectedModel.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            // Add context menu for deleting custom models
            .contextMenu {
                if model.isCustom {
                    Button(role: .destructive) {
                        viewModel.deleteCustomModel(model: model)
                    } label: {
                        Label("Delete Custom Model", systemImage: "trash")
                    }
                }
            }
        }
    }

    // .onDelete on a ForEach inside sections for mixed content (default/custom) is tricky.
    // The contextMenu approach on the modelRow is more direct for deleting specific custom models.
    // If you strictly need swipe-to-delete, you'd have a separate ForEach loop just for custom models
    // within each provider section, or a separate "Manage Custom Models" screen.
}
