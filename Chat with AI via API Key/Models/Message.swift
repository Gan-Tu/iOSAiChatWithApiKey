//
//  Message.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    enum Role {
        case user
        case assistant
        case error // To display API errors in the chat
    }
    let role: Role
    var content: String
    var isStreaming: Bool = false // For the last message being streamed
    var error: String? = nil // Store error message if role is .error
    
    var isLoadingPlaceholder: Bool = false // True if this is a temporary "Loading..." message

    // Convenience initializer for easier creation
    init(id: UUID = UUID(), role: Role, content: String, isStreaming: Bool = false, error: String? = nil, isLoadingPlaceholder: Bool = false) {
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
        self.error = error
        self.isLoadingPlaceholder = isLoadingPlaceholder
    }
}
