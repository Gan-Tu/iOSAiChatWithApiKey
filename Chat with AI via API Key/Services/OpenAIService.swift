//
//  OpenAIService.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//

import Foundation

// For "event: response.output_text.delta"
struct OpenAIResponsesAPIDeltaPayload: Decodable {
    let type: String // Should be "response.output_text.delta"
    // item_id, output_index, content_index are present
    let delta: String // This is the actual text token
}

// For "event: response.failed" or "event: error"
struct OpenAIResponsesAPIErrorPayload: Decodable {
    let type: String // e.g., "response.failed" or "error"
    struct ErrorDetail: Decodable {
        let code: String?
        let message: String
    }
    // For "response.failed", the error is nested under "response.error"
    struct ResponseWithError: Decodable {
        let error: ErrorDetail?
    }
    let response: ResponseWithError? // For "response.failed"
    let error: ErrorDetail?        // For "event: error"
}

class OpenAIService: NSObject, AIProviderService, URLSessionDataDelegate {

    private var dataTask: URLSessionDataTask?
    private var onTokenCallback: ((String) -> Void)?
    private var onCompleteCallback: ((Result<Void, AIProviderServiceError>) -> Void)?
    private var sseParser: SSEParser? // Now using the generic SSEParser
    private var session: URLSession?
    private var errorResponseDataBuffer: Data?

    func streamChatCompletion(
        model: ModelConfig,
        messages: [Message], // Our app's Message structs
        apiKey: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, AIProviderServiceError>) -> Void
    ) -> URLSessionDataTask? {

        self.onTokenCallback = onToken
        self.onCompleteCallback = onComplete
        self.errorResponseDataBuffer = Data()

        guard !apiKey.isEmpty else {
            onComplete(.failure(.apiKeyMissing))
            return nil
        }

        let urlString = "https://api.openai.com/v1/responses"
        guard let url = URL(urlString: urlString) else {
            onComplete(.failure(.invalidURL))
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let inputMessages: [[String: String]] = messages.filter { !$0.isLoadingPlaceholder }.map { message in
            return ["role": message.role == .user ? "user" : "assistant", "content": message.content]
        }

        var requestBodyDict: [String: Any] = [
            "model": model.modelName,
            "input": inputMessages,
            "stream": true
        ]
        
        if let effort = model.openAIReasoningEffort {
             // Note: Confirm if /v1/responses supports this.
             // requestBodyDict["reasoning"] = ["effort": effort]
             print("Warning: 'reasoning.effort' parameter usage with /v1/responses needs API doc confirmation.")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBodyDict, options: [])
            if let bodyStr = String(data: request.httpBody!, encoding: .utf8) {
                print("OpenAIService Request Body: \(bodyStr)")
            }
        } catch {
            onComplete(.failure(.streamingError("Failed to serialize request body: \(error.localizedDescription)")))
            return nil
        }

        // --- Initialize and use the generic SSEParser ---
        self.sseParser = SSEParser(
            onEvent: { [weak self] eventName, jsonDataString, eventId, retryInterval in
                // 'eventName' is from "event: <name>"
                // 'jsonDataString' is the string content from "data: <json_string>"
                guard let self = self else { return }

                guard let event = eventName, let dataStr = jsonDataString else {
                    // SSEParser might send nil for eventName if it's not specified,
                    // or nil for dataStr if the data field is empty.
                    // print("OpenAIService SSEParser: Received event with nil name or data. Event: \(String(describing: eventName))")
                    return
                }

                guard let jsonData = dataStr.data(using: .utf8) else {
                    self.onCompleteCallback?(.failure(.streamingError("OpenAI Parser: Failed to convert 'data' field to Data for event '\(event)'. Data: \(dataStr)")))
                    return
                }

                do {
                    switch event {
                    case "response.output_text.delta":
                        let payload = try JSONDecoder().decode(OpenAIResponsesAPIDeltaPayload.self, from: jsonData)
                        if payload.type == "response.output_text.delta", !payload.delta.isEmpty {
                            DispatchQueue.main.async { // Ensure token callback is on main thread
                                self.onTokenCallback?(payload.delta)
                            }
                        }

                    case "response.failed", "error":
                        let errorPayload = try JSONDecoder().decode(OpenAIResponsesAPIErrorPayload.self, from: jsonData)
                        var errorMessage = "API Error Event: \(event)"
                        if let apiError = errorPayload.error ?? errorPayload.response?.error {
                            errorMessage += " - \(apiError.message)"
                            if let code = apiError.code { errorMessage += " (Code: \(code))" }
                        } else {
                            errorMessage += " - Unknown error structure. Data: \(dataStr)"
                        }
                        DispatchQueue.main.async { // Ensure error callback is on main thread
                            self.onCompleteCallback?(.failure(.streamingError("OpenAI API Event Error: \(errorMessage)")))
                        }
                        // After a fatal API event error, you might want to stop processing further.
                        // This could involve cancelling the dataTask or setting a flag.

                    case "response.completed":
                        // print("OpenAIService SSEParser: Event - response.completed")
                        // The stream will naturally end, and URLSession delegate will handle completion.
                        break
                    
                    // Add other OpenAI specific event types from /v1/responses if needed
                    // response.created, response.output_item.added, etc.
                    default:
                        // print("OpenAIService SSEParser: Ignoring event: \(event)")
                        break
                    }
                } catch {
                    DispatchQueue.main.async {
                         self.onCompleteCallback?(.failure(.streamingError("OpenAI Parser: JSON Decoding Error for event '\(event)': \(error.localizedDescription). JSON: \(dataStr)")))
                    }
                }
            },
            onComplete: { [weak self] in
                // This onComplete is from SSEParser, meaning it processed all data given to it
                // via its parse() method before URLSession task itself completes.
                // print("OpenAIService: SSEParser finished its internal processing.")
                // The overall stream completion is handled by URLSession delegate.
            }
        )

        let sessionConfig = URLSessionConfiguration.default
        self.session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil) // Delegate queue nil for background processing
        self.dataTask = self.session?.dataTask(with: request)
        self.dataTask?.resume()

        return self.dataTask
    }

    // MARK: - URLSessionDataDelegate Methods

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            onCompleteCallback?(.failure(.invalidResponse))
            cleanup()
            return
        }

        if !(200...299).contains(httpResponse.statusCode) {
            print("OpenAIService: Received non-2xx HTTP status: \(httpResponse.statusCode)")
            completionHandler(.allow) // Allow receiving error body
        } else {
            errorResponseDataBuffer = nil // Not an error
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Check if we are buffering an error response based on the initial HTTP status
        if errorResponseDataBuffer != nil,
           let httpResponse = dataTask.response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            errorResponseDataBuffer?.append(data) // Accumulate data for the error body
        } else {
            // Normal data chunk, pass to the SSE parser
            // print("OpenAIService didReceive data for SSE: \(String(data: data, encoding: .utf8) ?? "Non-UTF8 data")")
            sseParser?.parse(data: data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { cleanup() } // Ensure cleanup happens

        if let anError = error as? URLError, anError.code == .cancelled {
            print("OpenAIService: Task cancelled.")
            onCompleteCallback?(.failure(.cancelled))
            return
        }
        
        // Signal the SSEParser that the stream of data chunks has ended from the URLSession side
        sseParser?.parseComplete() // Process any remaining buffer in SSEParser

        if let transportError = error { // Network/transport level error
            print("OpenAIService: Transport error: \(transportError.localizedDescription)")
            onCompleteCallback?(.failure(.networkError(transportError)))
            return
        }

        guard let httpResponse = task.response as? HTTPURLResponse else {
            onCompleteCallback?(.failure(.invalidResponse)) // Should have been caught earlier
            return
        }

        // Handle HTTP-level errors if not a transport error
        if !(200...299).contains(httpResponse.statusCode) {
            var errorMessage = "API Error (\(httpResponse.statusCode))"
            if let errorData = errorResponseDataBuffer, let errorString = String(data: errorData, encoding: .utf8) {
                // Try to parse known OpenAI error structure
                if let jsonData = try? JSONSerialization.jsonObject(with: errorData, options: []) as? [String: Any],
                   let errorDict = jsonData["error"] as? [String: Any],
                   let message = errorDict["message"] as? String {
                    errorMessage += ": \(message)"
                } else if !errorString.isEmpty {
                    errorMessage += ". Body: \(errorString)"
                }
            }
            print("OpenAIService: \(errorMessage)")
            onCompleteCallback?(.failure(.apiError(errorMessage, httpResponse.statusCode)))
            return
        }

        // If we reach here, the task completed with 2xx status and no transport error.
        // Any parsing errors or API-event errors should have been reported via sseParser's onEvent->onError.
        // If onCompleteCallback hasn't been called with a failure yet, it's a success.
        if self.onCompleteCallback != nil {
             // print("OpenAIService: Task completed successfully (2xx).")
             onCompleteCallback?(.success(()))
        }
    }

    private func cleanup() {
        session?.finishTasksAndInvalidate()
        session = nil
        dataTask = nil
        sseParser = nil // Release parser
        onTokenCallback = nil
        onCompleteCallback = nil // Nil out to prevent multiple calls
        errorResponseDataBuffer = nil
    }
}
