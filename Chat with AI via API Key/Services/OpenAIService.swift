//
//  OpenAIService.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

class OpenAIService: NSObject, AIProviderService, URLSessionDataDelegate {

    private var dataTask: URLSessionDataTask?
    private var onToken: ((String) -> Void)?
    private var onComplete: ((Result<Void, AIProviderServiceError>) -> Void)?
    private var openAIEventParser: OpenAIEventParser?
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

        // Construct the OpenAI messages format (simplified, ignoring tool_calls etc.)
        let openAIMessages = messages.map { msg in
            return [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }

        let urlString = "https://api.openai.com/v1/chat/completions" // Use chat/completions for standard chat API
        guard let url = URL(urlString: urlString) else {
            onComplete(.failure(.invalidURL))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let requestBody: [String: Any] = [
            "model": model.modelName,
            "messages": openAIMessages,
            "stream": true
            // Add instructions, temperature, etc. if needed from model config
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            onComplete(.failure(.streamingError("Failed to serialize request body: \(error.localizedDescription)")))
            return nil
        }

        self.onToken = onToken
        self.onComplete = onComplete

        // Need a session with a delegate to handle streaming data chunks
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session // Keep a reference
        self.dataTask = session.dataTask(with: request)

        self.openAIEventParser = OpenAIEventParser(
            onToken: { [weak self] token in
                 // Ensure token delivery happens on the main thread
                DispatchQueue.main.async {
                    self?.onToken?(token)
                }
            },
            onComplete: { [weak self] error in
                 // Completion will be handled by URLSession data task completion handler
                 // This internal parser complete is just a signal
            },
             onError: { [weak self] errorMessage in
                 // Report parsing error back to the main completion handler
                 self?.onComplete?(.failure(.streamingError("OpenAI parsing error: \(errorMessage)")))
             }
        )


        dataTask?.resume()

        return dataTask
    }

    // MARK: - URLSessionDataDelegate Methods

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // OpenAI sends data in 'data: {...}\n\n' format, often multiple events in one chunk
        openAIEventParser?.parse(data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { // Ensure completion handler is on main thread
            self.openAIEventParser?.parseComplete() // Process any leftover buffer

            if let error = error as? URLError, error.code == .cancelled {
                self.onComplete?(.failure(.cancelled))
            } else if let httpResponse = task.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                 // Attempt to read error from response body if available
                 // Note: This is tricky with streaming. The first non-2xx response might stop the stream.
                 // We might need to buffer the initial response if it's an error.
                 // For simplicity here, we'll just report a generic API error if status is bad.
                 // A more robust implementation would try to parse the error body.
                 self.onComplete?(.failure(.apiError("API returned status code \(httpResponse.statusCode)", httpResponse.statusCode)))
            } else if let error = error {
                self.onComplete?(.failure(.networkError(error)))
            } else {
                self.onComplete?(.success(())) // Success
            }

            // Clean up references
            self.onToken = nil
            self.onComplete = nil
            self.openAIEventParser = nil
            self.session = nil // Release the session
            self.dataTask = nil
        }
    }

    // Required by protocol, but not used for streaming delegate approach
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Check for non-2xx status early if possible
         if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             // Allow receiving data, but parse it as an error response instead of streaming events
             completionHandler(.allow) // Or cancel immediately? Depends on API specifics. Let's allow for now.
         } else {
            completionHandler(.allow)
         }
    }
}
