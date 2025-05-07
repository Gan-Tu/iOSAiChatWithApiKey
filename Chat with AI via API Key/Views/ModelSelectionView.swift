//
//  ModelSelectionView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct ModelSelectionView: View {
    @Environment(\.dismiss) var dismiss // For programmatically dismissing this sheet
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationView {
            List {
                // Section for Default Models (not deletable)
                Section(header: Text("Default Models")) {
                    ForEach(viewModel.allAvailableModels.filter { !$0.isCustom }) { model in
                        modelRow(for: model)
                    }
                }

                // Section for Custom Models (deletable)
                Section(header: Text("Custom Models")) {
                    ForEach(viewModel.allAvailableModels.filter { $0.isCustom }) { model in
                        modelRow(for: model)
                    }
                    .onDelete(perform: deleteCustomModelItems)
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 1. Tell ViewModel to prepare to show API Key sheet
                        viewModel.requestAPIKeyConfiguration()
                        // 2. Dismiss this ModelSelectionView sheet
                        dismiss()
                    } label: {
                        Label("API Keys", systemImage: "key.horizontal")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            // 1. Tell ViewModel to prepare to show the Add Custom Model sheet
                            viewModel.showAddCustomModelSheet = true
                            // 2. Dismiss this ModelSelectionView sheet immediately
                            //    This allows ContentView to pick up the state change and present the new sheet.
                            dismiss()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        
                        Button("Done") {
                            dismiss() // Just dismiss this sheet
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func modelRow(for model: ModelConfig) -> some View {
        Button {
            viewModel.selectModel(model) // This will set selectedModel and save it
            dismiss()                    // Then dismiss this sheet
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(model.displayName)
                        .foregroundColor(.primary)
                    Text("ID: \(model.modelName) (\(model.provider.name))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                if model.id == viewModel.selectedModel.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    private func deleteCustomModelItems(at offsets: IndexSet) {
        let customModelsInView = viewModel.allAvailableModels.filter { $0.isCustom }
        let modelsToDelete = offsets.map { customModelsInView[$0] }
        
        for model in modelsToDelete {
            viewModel.deleteCustomModel(model: model)
        }
    }
}
