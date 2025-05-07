//
//  SSEParser.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

class SSEParser {
    typealias OnEvent = (_ event: String?, _ data: String?, _ id: String?, _ retry: Int?) -> Void
    typealias OnComplete = () -> Void

    private var buffer = ""
    private var onEvent: OnEvent
    private var onComplete: OnComplete

    init(onEvent: @escaping OnEvent, onComplete: @escaping OnComplete) {
        self.onEvent = onEvent
        self.onComplete = onComplete
    }

    func parse(data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        // SSE messages are delimited by double newlines
        let lines = buffer.components(separatedBy: "\n")
        buffer = lines.last ?? "" // Keep the incomplete last line in the buffer

        for i in 0..<(lines.count - 1) {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // End of a message, process buffered event data
                processBufferedEvent()
            } else {
                bufferEventLine(line)
            }
        }
    }

    func parseComplete() {
        // Process any remaining data in the buffer
        if !buffer.isEmpty {
             bufferEventLine(buffer)
             processBufferedEvent()
        }
        onComplete()
    }

    // --- Internal State for buffering event parts ---
    private var currentEvent: String?
    private var currentData = ""
    private var currentId: String?
    private var currentRetry: Int?

    private func bufferEventLine(_ line: String) {
        if line.hasPrefix(":") {
            // Comment line, ignore
            return
        }

        let separatorIndex = line.firstIndex(of: ":") ?? line.endIndex
        let field = String(line[..<separatorIndex])
        var value = String(line[separatorIndex...])
        if value.hasPrefix(":") {
            value = String(value.dropFirst())
            if value.hasPrefix(" ") {
                 value = String(value.dropFirst())
            }
        }

        switch field {
        case "event":
            currentEvent = value
        case "data":
            // Data can be multiline. Append a newline if this isn't the first data line.
            if !currentData.isEmpty {
                currentData += "\n"
            }
            currentData += value
        case "id":
            currentId = value
        case "retry":
            currentRetry = Int(value)
        default:
            // Unknown field, ignore
            break
        }
    }

    private func processBufferedEvent() {
        // Don't process if there's no data field (unless it's a [DONE] signal)
        guard !currentData.isEmpty || currentEvent == nil && currentId == nil && currentRetry == nil else {
            // Potentially an incomplete event or comment-only block
            // Clear buffer state and wait for more data
             clearBufferedEventState()
             return
        }

        // Special case: [DONE] signal from some APIs
        if currentData == "[DONE]" {
            clearBufferedEventState()
            // Handle [DONE] as a completion signal, not a regular event
            // onComplete() will be called from parseComplete or external handler
            return
        }

        // Trigger the event callback
        onEvent(currentEvent, currentData, currentId, currentRetry)

        // Clear the buffered state for the next event
        clearBufferedEventState()
    }

    private func clearBufferedEventState() {
        currentEvent = nil
        currentData = ""
        currentId = nil
        currentRetry = nil
    }
}

