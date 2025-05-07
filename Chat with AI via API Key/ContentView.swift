//
//  ContentView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//
import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ChatViewModel()
    @State private var showingModelSelection = false

    // Use ScrollViewReader to scroll to the bottom
    @Namespace var bottomID

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Chat Messages Area
                ScrollView {
                    ScrollViewReader { proxy in
                        // FIX 8: Auto-scroll logic is here. Keep the asyncAfter.
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id) // Add ID for scrolling
                            }
                        }
                        .padding(.top, 8) // Added slightly more top padding
                        .padding(.bottom, 8) // Added slightly more bottom padding
                        .onChange(of: viewModel.messages.count) { _ in
                            // Scroll to the bottom when a new message is added
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Keep the delay
                                 scrollToBottom(proxy: proxy)
                             }
                        }
                        .onAppear {
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { // Keep the delay
                                  scrollToBottom(proxy: proxy)
                              }
                         }
                    }
                }
                // Ignore keyboard safe area so the scroll view extends behind it
                .ignoresSafeArea(.keyboard, edges: .bottom)


                // Input Area - Pass the expand action
                InputAreaView(
                    inputText: $viewModel.inputText,
                    onSend: { viewModel.sendMessage() },
                    isLoading: viewModel.isLoading,
                    onExpand: { viewModel.expandInputArea() } // FIX 1: Pass the expand action
                )
            }
            .navigationTitle(viewModel.selectedModel.displayName) // Use selected model name
            .navigationBarTitleDisplayMode(.inline) // Minimalist title
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Make the title tappable to show model selection
                    Button(action: {
                        showingModelSelection = true
                    }) {
                        HStack {
                            Text(viewModel.selectedModel.displayName)
                            Image(systemName: "chevron.down") // Down arrow indicator
                                .font(.caption)
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                    }
                }
                 // FIX 3: Add New Chat Button
                 ToolbarItem(placement: .navigationBarTrailing) {
                     HStack {
                         // Cancel button (optional, keep for usefulness)
                         if viewModel.isLoading {
                             Button("Cancel") {
                                 viewModel.cancelStreaming()
                             }
                         }
                         // New Chat Button
                         Button {
                             viewModel.startNewChat()
                         } label: {
                             Image(systemName: "square.and.pencil") // System icon for new
                         }
                     }
                 }
            }
            .sheet(isPresented: $showingModelSelection) {
                ModelSelectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAPIKeyConfigSheet) {
                 APIKeyConfigView(viewModel: viewModel)
            }
            // FIX 1: Add the sheet for the expanded input view
            .sheet(isPresented: $viewModel.showExpandedInputSheet) {
                 ExpandedInputView(text: $viewModel.inputText) // Bind directly to the input text
                     // No explicit onDismiss needed if binding handles state
            }
        }
        // Hide keyboard when scrolling
        .simultaneousGesture(DragGesture().onChanged { _ in
             UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
         })
         // Add background color to the entire view that ignores safe area
         .background(Color(UIColor.systemBackground).ignoresSafeArea())
    }

     // FIX 8: Auto-scroll function
     private func scrollToBottom(proxy: ScrollViewProxy) {
         // Find the last message ID
         if let lastMessageID = viewModel.messages.last?.id {
             // Scroll to the last message ID with animation
             proxy.scrollTo(lastMessageID, anchor: .bottom)
         }
     }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
