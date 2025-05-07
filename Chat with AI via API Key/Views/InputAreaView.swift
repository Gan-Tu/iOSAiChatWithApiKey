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
    let isLoading: Bool // To disable the send button

    // Determine if the send button should be active
    private var isSendButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }

    var body: some View {
        HStack {
            TextField("Hello", text: $inputText, axis: .vertical) // Use vertical axis for multiline
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 8)
                .disabled(isLoading) // Disable text field while loading

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(isSendButtonDisabled ? .gray : .blue)
            }
            .disabled(isSendButtonDisabled)
        }
        .padding(.horizontal)
        .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0) // Pad for software keyboard/safe area
        .background(Color(UIColor.systemGray6).ignoresSafeArea(.all, edges: .bottom))
    }
}

struct InputAreaView_Previews: PreviewProvider {
    static var previews: some View {
        InputAreaView(inputText: .constant(""), onSend: {}, isLoading: false)
            .previewLayout(.sizeThatFits)
        InputAreaView(inputText: .constant("Typing something..."), onSend: {}, isLoading: false)
            .previewLayout(.sizeThatFits)
        InputAreaView(inputText: .constant("Loading..."), onSend: {}, isLoading: true)
            .previewLayout(.sizeThatFits)
    }
}
