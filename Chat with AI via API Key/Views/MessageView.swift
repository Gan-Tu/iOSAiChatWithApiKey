//
//  MessageView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//
import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer() // Push user message to the right
            }

            VStack(alignment: .leading) {
                if message.role == .error {
                    Text(message.content)
                        .foregroundColor(.red)
                        .padding(.all, 15) // FIX 7: Increased padding
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                } else {
                    // FIX 5: Only show the bubble content if content is not empty
                    if !message.content.isEmpty {
                         Text(.init(message.content))
                             .multilineTextAlignment(.leading)
                             .padding(.all, 15) // FIX 7: Increased padding
                             .background(bubbleColor)
                             .foregroundColor(textColor)
                             .cornerRadius(10)
                             // Optional: Add a max width to bubbles
                              .frame(maxWidth: UIScreen.main.bounds.width * 0.9, alignment: message.role == .user ? .trailing : .leading)
                     }
                    // FIX 4 & 5: Remove the spinning loading indicator here.
                    // The bubble not appearing until the first token is the new indicator.
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)


            if message.role == .assistant || message.role == .error {
                Spacer() // Push assistant/error message to the left
            }
        }
        .padding(.horizontal, 10) // Horizontal padding for chat bubble alignment
        .padding(.vertical, 2) // Add slight vertical padding between bubbles
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : Color(UIColor.systemGray6)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) { // Added spacing for preview
            MessageView(message: Message(role: .user, content: "Hello, world!"))
            MessageView(message: Message(role: .assistant, content: "Hi there! How can I help you today?"))
            MessageView(message: Message(role: .assistant, content: "This is **bold** text, this is *italic* text, and this is ***bold, italic*** text."))
             // Preview for an empty streaming message (should be hidden)
            MessageView(message: Message(role: .assistant, content: "", isStreaming: true))
            MessageView(message: Message(role: .error, content: "Error: API key is missing."))
             MessageView(message: Message(role: .user, content: "This is a much longer message that wraps around multiple lines to test padding and width constraints."))
             MessageView(message: Message(role: .assistant, content: "This is an assistant response that is also quite lengthy and should wrap properly within its maximum width."))
        }
        .padding()
        .background(Color.gray.opacity(0.1)) // Add background for visibility
    }
}
