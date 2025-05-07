//
//  APIKeyConfigView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct APIKeyConfigView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ChatViewModel

    // Local state for the API key text fields
    @State private var openaiKey: String = ""
    @State private var xaiKey: String = ""
    @State private var geminiKey: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter API Keys")) {
                    TextField("OpenAI API Key", text: $openaiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("xAI API Key", text: $xaiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    TextField("Gemini API Key", text: $geminiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button("Save Keys") {
                        viewModel.saveAPIKey(openaiKey, for: .openai)
                        viewModel.saveAPIKey(xaiKey, for: .xai)
                        viewModel.saveAPIKey(geminiKey, for: .gemini)
                        // Check keys again to see if the required one is now present
                        viewModel.checkAPIKeys()
                        // If checkAPIKeys() sets showAPIKeyConfigSheet to false,
                        // the sheet will be dismissed automatically.
                    }
                }
            }
            .navigationTitle("Configure API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load existing keys when the view appears
                openaiKey = viewModel.getAPIKey(for: .openai) ?? ""
                xaiKey = viewModel.getAPIKey(for: .xai) ?? ""
                geminiKey = viewModel.getAPIKey(for: .gemini) ?? ""
            }
        }
    }
}

struct APIKeyConfigView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeyConfigView(viewModel: ChatViewModel())
    }
}

