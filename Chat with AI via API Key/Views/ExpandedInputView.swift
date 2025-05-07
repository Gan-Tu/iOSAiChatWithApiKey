//
//  ExpandedInputView.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import SwiftUI

struct ExpandedInputView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var text: String // Bind to the text state in ViewModel

    var body: some View {
        NavigationView {
            VStack {
                // Use TextEditor for multi-line input
                TextEditor(text: $text)
                    .cornerRadius(5)
                    .padding() // Padding outside the TextEditor

                Spacer() // Push content to the top
            }
            .navigationTitle("Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // Dismiss the sheet
                    }
                }
            }
        }
    }
}

struct ExpandedInputView_Previews: PreviewProvider {
    static var previews: some View {
        ExpandedInputView(text: .constant("This is some text that needs a lot of space to edit."))
    }
}
