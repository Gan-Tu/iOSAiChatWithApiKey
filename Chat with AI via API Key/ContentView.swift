//
//  ContentView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ChatViewModel()
    // showingModelSelection is local state for this view to present ModelSelectionView
    @State private var showingModelSelection = false

    @Namespace var bottomID

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ... (ScrollView for messages remains the same)
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .onChange(of: viewModel.messages.count) { _ in
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                 scrollToBottom(proxy: proxy)
                             }
                        }
                        .onAppear {
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                  scrollToBottom(proxy: proxy)
                              }
                         }
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)


                InputAreaView(
                    inputText: $viewModel.inputText,
                    onSend: { viewModel.sendMessage() },
                    isLoading: viewModel.isLoading,
                    onExpand: { viewModel.expandInputArea() }
                )
            }
            .navigationTitle(viewModel.selectedModel.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        showingModelSelection = true // Use local state to show model selection
                    }) {
                        HStack {
                            Text(viewModel.selectedModel.displayName)
                            Image(systemName: "chevron.down").font(.caption)
                        }
                        .font(.headline).foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                     HStack {
                         if viewModel.isLoading { Button("Cancel") { viewModel.cancelStreaming() } }
                         Button { viewModel.startNewChat() } label: { Image(systemName: "plus.circle") }
                     }
                 }
            }
            .sheet(isPresented: $showingModelSelection) { // Changed to local state
                ModelSelectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAPIKeyConfigSheet) {
                 APIKeyConfigView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showExpandedInputSheet) {
                 ExpandedInputView(text: $viewModel.inputText)
            }
            // --- Add sheet for adding custom models ---
            .sheet(isPresented: $viewModel.showAddCustomModelSheet) {
                AddEditCustomModelView(viewModel: viewModel)
            }
        }
        .simultaneousGesture(DragGesture().onChanged { _ in
             UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
         })
         .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }

     private func scrollToBottom(proxy: ScrollViewProxy) {
         if let lastMessageID = viewModel.messages.last?.id {
             proxy.scrollTo(lastMessageID, anchor: .bottom)
         }
     }
}
