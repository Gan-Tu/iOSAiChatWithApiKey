//
//  OpenAIEventParser.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

struct OpenAIEvent<T: Decodable>: Decodable {
    let type: String
    let data: T
}

struct OpenAIResponseCreatedData: Decodable {
    struct Response: Decodable {
        let id: String
        let object: String
        let status: String
        let model: String?
    }
    let response: Response
}

struct OpenAIOutputTextDeltaData: Decodable {
    let item_id: String
    let output_index: Int
    let content_index: Int
    let delta: String
}

struct OpenAIResponseCompletedData: Decodable {
     struct Response: Decodable {
         let id: String
         let status: String
         // Add other fields if needed, like usage
     }
    let response: Response
}


class OpenAIEventParser {
    typealias OnToken = (String) -> Void
    typealias OnComplete = (Error?) -> Void
    typealias OnError = (String) -> Void // For parsing/API errors

    private var buffer = ""
    private let onToken: OnToken
    private let onComplete: OnComplete
    private let onError: OnError

    init(onToken: @escaping OnToken, onComplete: @escaping OnComplete, onError: @escaping OnError) {
        self.onToken = onToken
        self.onComplete = onComplete
        self.onError = onError
    }

    func parse(data: Data) {
         guard let chunk = String(data: data, encoding: .utf8) else {
             onError("Failed to decode data chunk")
             return
         }
         buffer += chunk

         processBuffer()
     }

     func parseComplete() {
         // Process any remaining buffer just in case
         processBuffer()
         onComplete(nil) // Assume success unless an error was reported earlier
     }

     private func processBuffer() {
         while let range = buffer.range(of: "\n\n") {
             let eventString = String(buffer[..<range.lowerBound])
             buffer.removeSubrange(..<range.upperBound)

             // Process the event string
             processEventString(eventString)
         }
     }

    private func processEventString(_ eventString: String) {
        let lines = eventString.components(separatedBy: "\n")
        var eventType: String?
        var eventDataString: String?

        for line in lines {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst("event: ".count))
            } else if line.hasPrefix("data: ") {
                eventDataString = String(line.dropFirst("data: ".count))
            }
             // Ignore other fields like id, retry, etc. for simplicity based on provided spec
        }

        guard let type = eventType, let dataString = eventDataString else {
            // Might be a comment or incomplete event, ignore for now
            // print("Warning: Skipping incomplete event: \(eventString)")
            return
        }

        // Handle the known event types
        switch type {
        case "response.output_text.delta":
            // This event contains the actual text delta
            if let jsonData = dataString.data(using: .utf8) {
                do {
                    let deltaEvent = try JSONDecoder().decode(OpenAIEvent<OpenAIOutputTextDeltaData>.self, from: jsonData)
                    onToken(deltaEvent.data.delta)
                } catch {
                    onError("Failed to parse output_text.delta: \(error.localizedDescription)")
                    // print("Failed to parse output_text.delta JSON: \(dataString) - Error: \(error)")
                }
            } else {
                 onError("Failed to create data from output_text.delta string")
            }
        case "response.completed":
            // Indicates the completion of the response
            // No action needed here usually, completion handled by parseComplete
             // But we could potentially extract final info if needed
             // print("OpenAI response completed")
            break
        // Add other event types if needed, e.g., "response.created", "response.output_item.added"
        default:
            // print("Ignoring OpenAI event type: \(type)")
            break
        }
    }
}
