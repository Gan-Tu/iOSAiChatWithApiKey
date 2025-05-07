//
//  ModelSelectionView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//
import SwiftUI

struct ModelSelectionView: View {
    @Environment(\.dismiss) var dismiss // Get the dismiss action
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(Provider.allCases) { provider in
                    Section(header: Text(provider.name)) {
                        ForEach(viewModel.availableModels.filter { $0.provider == provider }) { model in
                            Button {
                                viewModel.selectModel(model)
                                dismiss() // Dismiss the sheet after selection
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if model.id == viewModel.selectedModel.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Add the API Key configuration button
                ToolbarItem(placement: .navigationBarLeading) { // Leading or Trailing, your choice
                    Button {
                        // Request the API key config sheet via the ViewModel
                        viewModel.requestAPIKeyConfiguration()
                        // Dismiss this model selection sheet
                        dismiss()
                    } label: {
                        Label("Configure API Keys", systemImage: "key.horizontal")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // Dismiss the sheet
                    }
                }
            }
        }
    }
}

struct ModelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSelectionView(viewModel: ChatViewModel())
    }
}

