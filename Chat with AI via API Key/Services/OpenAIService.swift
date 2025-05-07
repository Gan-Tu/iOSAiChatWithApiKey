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

        // Construct the OpenAI messages format (simplified)
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

        var requestBody: [String: Any] = [
            "model": model.modelName,
            "messages": openAIMessages,
            "stream": true
            // Add temperature, etc. if needed from model config
        ]

        // FIX 6: Add reasoning parameter for o4-mini if specified in model config
        if let effort = model.openAIReasoningEffort {
             requestBody["reasoning"] = ["effort": effort]
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
        self.session = session // Keep a reference
        self.dataTask = session.dataTask(with: request)

        self.openAIEventParser = OpenAIEventParser(
            onToken: { [weak self] token in
                 DispatchQueue.main.async {
                     self?.onToken?(token)
                 }
            },
            onComplete: { [weak self] error in
                 // Parser completion is less critical than task completion
                 // print("OpenAI Parser Complete") // Debugging
            },
             onError: { [weak self] errorMessage in
                 print("OpenAI Parsing Error: \(errorMessage)") // Debugging
                 self?.onComplete?(.failure(.streamingError("OpenAI parsing error: \(errorMessage)")))
             }
        )


        dataTask?.resume()

        return dataTask
    }

    // MARK: - URLSessionDataDelegate Methods (No changes needed here from previous version)

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        openAIEventParser?.parse(data: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { // Ensure completion handler is on main thread
            self.openAIEventParser?.parseComplete() // Process any leftover buffer

            if let error = error as? URLError, error.code == .cancelled {
                self.onComplete?(.failure(.cancelled))
            } else if let httpResponse = task.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                 print("OpenAI API Error Status: \(httpResponse.statusCode)") // Debugging
                 self.onComplete?(.failure(.apiError("API returned status code \(httpResponse.statusCode)", httpResponse.statusCode)))
            } else if let error = error {
                print("OpenAI Network/Task Error: \(error.localizedDescription)") // Debugging
                self.onComplete?(.failure(.networkError(error)))
            } else {
                // print("OpenAI Task Completed Successfully") // Debugging
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

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
         if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             completionHandler(.allow)
         } else {
            completionHandler(.allow)
         }
    }
}
