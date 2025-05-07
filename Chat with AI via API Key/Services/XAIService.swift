//
//  XAIService.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

// Re-using struct definitions from previous fix that work with raw data payload
struct XAICompletionChunkData: Decodable {
    let id: String
    let object: String // Should be "chat.completion.chunk"
    let created: Int
    let model: String
    let choices: [Choice] // Array of Choice objects

    struct Choice: Decodable {
        let index: Int
        let delta: Delta? // Delta object is optional (e.g., in the final chunk with finish_reason)
        let finish_reason: String? // Optional, as it's only present on the final chunk

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finish_reason
        }
    }

    struct Delta: Decodable {
        let content: String?
        let role: String?
    }
}

class XAIService: NSObject, AIProviderService, URLSessionDataDelegate {
    private var dataTask: URLSessionDataTask?
    private var onToken: ((String) -> Void)?
    private var onComplete: ((Result<Void, AIProviderServiceError>) -> Void)?
    private var sseParser: SSEParser?
     private var session: URLSession?

    func streamChatCompletion(
        model: ModelConfig,
        messages: [Message],
        apiKey: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, AIProviderServiceError>) -> Void
    ) -> URLSessionDataTask? {

        guard !apiKey.isEmpty else {
            onComplete(.failure(.apiKeyMissing))
            return nil
        }

        let xaiMessages = messages.map { msg in
            return [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }

        let urlString = "https://api.x.ai/v1/chat/completions"
        guard let url = URL(urlString: urlString) else {
            onComplete(.failure(.invalidURL))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var requestBody: [String: Any] = [
            "messages": xaiMessages,
            "model": model.modelName,
            "stream": true,
            "temperature": 0.0 // Example, can be configurable
        ]

        // FIX 6: Add reasoning parameter for xAI mini if specified
        if let effort = model.xAIReasoningEffort {
            requestBody["reasoning_effort"] = effort
        }


        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            onComplete(.failure(.streamingError("Failed to serialize request body: \(error.localizedDescription)")))
            return nil
        }

        self.onToken = onToken
        self.onComplete = onComplete

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        self.dataTask = session.dataTask(with: request)

        self.sseParser = SSEParser(
            onEvent: { [weak self] event, data, id, retry in
                 if let data = data {
                     if data == "[DONE]" {
                         // print("XAI received [DONE]")
                     } else {
                          guard !data.isEmpty else {
                              // print("XAI received empty data field, ignoring.")
                              return
                          }

                         if let jsonData = data.data(using: .utf8) {
                             do {
                                 // Decode the data directly into XAICompletionChunkData
                                 let chunk = try JSONDecoder().decode(XAICompletionChunkData.self, from: jsonData)

                                 // Process the chunk - look for the delta content
                                 if let choice = chunk.choices.first, // Get the first choice
                                    let delta = choice.delta,      // Check if delta object exists
                                    let content = delta.content { // Check if content string exists inside delta
                                       DispatchQueue.main.async {
                                           self?.onToken?(content) // Pass the extracted content (can be "")
                                       }
                                  } else {
                                      // Ignore chunks without the expected text delta content
                                       // print("XAI chunk has no usable text delta.")
                                  }

                             } catch {
                                 print("Failed to parse xAI data JSON: \(data) - Error: \(error)")
                                 DispatchQueue.main.async {
                                      self?.onComplete?(.failure(.streamingError("xAI JSON decoding error: \(error.localizedDescription) - Data: \(data)")))
                                 }
                             }
                         } else {
                             print("Failed to create data from xAI data string: \(data)")
                              DispatchQueue.main.async {
                                   self?.onComplete?(.failure(.streamingError("xAI data string invalid encoding: \(data)")))
                              }
                         }
                     }
                 }
             },
            onComplete: { [weak self] in
                 // print("XAI SSE Parser Complete")
             }
        )

        dataTask?.resume()

        return dataTask
    }

    // MARK: - URLSessionDataDelegate Methods (Same as OpenAI, using SSEParser)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // print("XAI didReceive data: \(String(data: data, encoding: .utf8) ?? "nil")") // Debugging raw data
        sseParser?.parse(data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
             self.sseParser?.parseComplete() // Process any remaining buffer

            if let error = error as? URLError, error.code == .cancelled {
                self.onComplete?(.failure(.cancelled))
            } else if let httpResponse = task.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                 // Try to read error body if possible - needs buffering the response
                 // For now, log and report generic API error
                 print("XAI API Error Status: \(httpResponse.statusCode)") // Debugging
                 self.onComplete?(.failure(.apiError("API returned status code \(httpResponse.statusCode)", httpResponse.statusCode)))
            } else if let error = error {
                print("XAI Network/Task Error: \(error.localizedDescription)") // Debugging
                self.onComplete?(.failure(.networkError(error)))
            } else {
                 // print("XAI Task Completed Successfully") // Debugging
                self.onComplete?(.success(()))
            }

            // Clean up references
            self.onToken = nil
            self.onComplete = nil
            self.sseParser = nil
            self.session = nil
            self.dataTask = nil
        }
    }

     func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Check for non-2xx status early
         if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             // Note: If API sends an error body, this might stop the stream.
             // Allowing data reception here is standard, but parsing the error body
             // requires buffering the initial response before the delegate methods.
             // For simplicity, we rely on didCompleteWithError to catch bad status codes.
             completionHandler(.allow)
         } else {
            completionHandler(.allow)
         }
    }
}
