//
//  InputAreaView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct InputAreaView: View {
    @Binding var inputText: String
    let onSend: () -> Void
    let isLoading: Bool
    let onExpand: () -> Void
    
    // Determine if the send button should be active
    private var isSendButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Input area with buttons
            HStack(alignment: .bottom, spacing: 8) {
                // Text input area
                ZStack(alignment: .leading) {
                    // Placeholder text
                    if inputText.isEmpty {
                        Text("This")
                            .foregroundColor(Color.gray.opacity(0.7))
                            .padding(.leading, 4)
                            .padding(.top, 8)
                            .allowsHitTesting(false) // Ensure this doesn't block TextEditor interaction
                    }
                    
                    // Actual text editor - fully editable
                    TextEditor(text: $inputText)
                        .frame(minHeight: 36, maxHeight: 100)
                        .disabled(isLoading) // Only disable when loading
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.horizontal, 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 36)
                
                // Expand button (positioned absolutely)
                VStack {
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(90))
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Send button
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(isSendButtonDisabled ? Color.gray.opacity(0.5) : Color.blue)
                    }
                    .disabled(isSendButtonDisabled)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.systemGray6))
    }
}

struct InputAreaView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            InputAreaView(
                inputText: .constant("Short"),
                onSend: {},
                isLoading: false,
                onExpand: {}
            )
            .previewLayout(.sizeThatFits)
            
            InputAreaView(
                inputText: .constant("This is a slightly longer message that might take up more than one line."),
                onSend: {},
                isLoading: false,
                onExpand: {}
            )
            .previewLayout(.sizeThatFits)
            
            let longText = String(repeating: "A", count: 60) + " Long text to trigger expand button visibility."
            InputAreaView(
                inputText: .constant(longText),
                onSend: {},
                isLoading: false,
                onExpand: {}
            )
            .previewLayout(.sizeThatFits)
            
            InputAreaView(
                inputText: .constant("Line 1\nLine 2\nLine 3\nLine 4"),
                onSend: {},
                isLoading: false,
                onExpand: {}
            )
            .previewLayout(.sizeThatFits)
            
            InputAreaView(
                inputText: .constant("Loading..."),
                onSend: {},
                isLoading: true,
                onExpand: {}
            )
            .previewLayout(.sizeThatFits)
        }
        .background(Color.yellow.opacity(0.3).ignoresSafeArea()) // Visualize padding
    }
}
