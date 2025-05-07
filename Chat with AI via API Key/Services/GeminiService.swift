//
//  GeminiService.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//


import Foundation

class GeminiService: NSObject, AIProviderService, URLSessionDataDelegate {

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

        // Gemini uses a different message structure (contents, parts)
        let geminiContents = messages.map { msg in
            return [
                "role": msg.role == .user ? "user" : "model", // Gemini uses 'model' for assistant
                "parts": [["text": msg.content]]
            ]
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.modelName):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(urlString: urlString) else {
            onComplete(.failure(.invalidURL))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Gemini uses key in URL, not Auth header

        let requestBody: [String: Any] = [
            "contents": geminiContents
            // Add generationConfig, safetySettings etc. if needed
        ]

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
                 // Process SSE 'data' field
                 if let data = data, let jsonData = data.data(using: .utf8) {
                     // Parse the JSON within the data field
                     do {
                         // Gemini response contains an array of candidates/parts
                         let chunk = try JSONDecoder().decode(GeminiResponseChunk.self, from: jsonData)
                         if let text = chunk.candidates?.first?.content.parts.first?.text {
                             DispatchQueue.main.async { // Ensure token delivery happens on the main thread
                                 self?.onToken?(text)
                             }
                         }
                     } catch {
                          // print("Failed to parse Gemini data JSON: \(data) - Error: \(error)")
                          DispatchQueue.main.async {
                               self?.onComplete?(.failure(.streamingError("Gemini parsing error: \(error.localizedDescription)")))
                          }
                     }
                 }
             },
            onComplete: { [weak self] in
                 // Internal parser complete
             }
        )

        dataTask?.resume()

        return dataTask
    }

     // MARK: - Helper structs for Gemini JSON chunk parsing
     struct GeminiResponseChunk: Decodable {
         let candidates: [Candidate]?
         // usageMetadata, modelVersion might also be present

         struct Candidate: Decodable {
             let content: Content
             let finishReason: String? // e.g., "STOP", "MAX_TOKENS"
             let index: Int? // Usually 0 for single candidate
         }

         struct Content: Decodable {
             let parts: [Part]
             let role: String? // e.g., "model"
         }

         struct Part: Decodable {
             let text: String? // Text content
             // inlineData, etc.
         }
     }


    // MARK: - URLSessionDataDelegate Methods (Same as OpenAI/XAI, using SSEParser)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        sseParser?.parse(data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
             self.sseParser?.parseComplete() // Process any remaining buffer

            if let error = error as? URLError, error.code == .cancelled {
                self.onComplete?(.failure(.cancelled))
            } else if let httpResponse = task.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                 self.onComplete?(.failure(.apiError("API returned status code \(httpResponse.statusCode)", httpResponse.statusCode)))
            } else if let error = error {
                self.onComplete?(.failure(.networkError(error)))
            } else {
                // Check if the SSEParser finished successfully.
                // If the stream ended without an error but the parser didn't get a clear "done" signal
                // or if there were parsing errors, the streamingError might have been reported already.
                // We assume success here if error is nil, unless a parsing error was specifically reported via onComplete(.failure(.streamingError(...))) earlier.
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
             completionHandler(.allow) // Allow receiving error body
         } else {
            completionHandler(.allow)
         }
     }
}

// Helper extension for creating URLs robustly
extension URL {
    init?(urlString: String) {
        // URLComponents can help with complex URLs, but a simple check is ok too
        if let url = URL(string: urlString) {
            self = url
        } else {
            return nil
        }
    }
}
