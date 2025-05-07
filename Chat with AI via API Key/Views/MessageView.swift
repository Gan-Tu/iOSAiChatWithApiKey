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
                        .padding(.all, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                } else {
                    Text(message.content)
                        .padding(.all, 10)
                        .background(bubbleColor)
                        .foregroundColor(textColor)
                        .cornerRadius(10)

                    if message.isStreaming {
                        // Simple streaming indicator
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            .padding(.leading, 8)
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)


            if message.role == .assistant || message.role == .error {
                Spacer() // Push assistant/error message to the left
            }
        }
        .padding(.horizontal, 10) // Horizontal padding for chat bubble alignment
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
        VStack {
            MessageView(message: Message(role: .user, content: "Hello, world!"))
            MessageView(message: Message(role: .assistant, content: "Hi there! How can I help you today?"))
            MessageView(message: Message(role: .assistant, content: "This is a streaming message...", isStreaming: true))
            MessageView(message: Message(role: .error, content: "Error: API key is missing."))
        }
        .padding()
    }
}

