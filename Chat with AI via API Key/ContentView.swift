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
        // FIX 2 & 3: Ensure NavigationView and VStack allow content to fill screen and handle keyboard
        NavigationView {
            VStack(spacing: 0) { // Use spacing 0 to remove gap between chat and input
                // Chat Messages Area
                // FIX 3: ScrollView is already here, ensure it behaves correctly
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 8) { // Use LazyVStack for performance with many messages
                            ForEach(viewModel.messages) { message in
                                MessageView(message: message)
                                    .id(message.id) // Add ID for scrolling
                            }
                        }
                        .padding(.top, 1) // Small padding at the top
                        .padding(.bottom, 1) // Small padding at the bottom to ensure last message isn't cutoff by input area slightly
                        .onChange(of: viewModel.messages.count) { _ in
                            // Scroll to the bottom when a new message is added
                            // Use a small delay to ensure layout updates before scrolling
                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                 scrollToBottom(proxy: proxy)
                             }
                        }
                        .onAppear {
                             // Initial scroll on appearance if there are messages
                              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                  scrollToBottom(proxy: proxy)
                              }
                         }
                    }
                }
                 // FIX 2 & 3: Allow ScrollView to go behind the keyboard
                 // The InputAreaView handles its own padding for the bottom safe area/keyboard height
                 .ignoresSafeArea(.keyboard, edges: .bottom) // This is crucial for keyboard handling and scrolling

                // Input Area
                InputAreaView(
                    inputText: $viewModel.inputText,
                    onSend: { viewModel.sendMessage() },
                    isLoading: viewModel.isLoading
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
                 // Optionally add a Cancel button for streaming
                 ToolbarItem(placement: .navigationBarTrailing) {
                     if viewModel.isLoading {
                         Button("Cancel") {
                             viewModel.cancelStreaming()
                         }
                     }
                 }
            }
            .sheet(isPresented: $showingModelSelection) {
                ModelSelectionView(viewModel: viewModel)
                     // When the model selection sheet is dismissed, we don't need to do anything
                     // explicitly here regarding the API key sheet, as the ViewModel's
                     // `showAPIKeyConfigSheet` state is observed by ContentView directly.
                     // If ModelSelectionView requests config, it dismisses itself,
                     // ViewModel updates state, and ContentView presents APIKeyConfigView.
            }
            .sheet(isPresented: $viewModel.showAPIKeyConfigSheet) {
                 APIKeyConfigView(viewModel: viewModel)
                     // The APIKeyConfigView will handle saving and updating ViewModel state
                     // ViewModel's state change will automatically dismiss the sheet if needed
            }
        }
        // Optional: Hide keyboard when scrolling
        // This gesture is simultaneous, meaning it works alongside the scroll gesture.
        // It should not prevent scrolling.
        .simultaneousGesture(DragGesture().onChanged { _ in
             UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
         })
         // FIX 2: Add background color to the entire view that ignores safe area
         // This ensures the background extends edge-to-edge behind the status bar and keyboard
         .background(Color(UIColor.systemBackground).ignoresSafeArea()) // Use systemBackground or a specific color
    }

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
