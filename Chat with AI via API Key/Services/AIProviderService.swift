//
//  AIProviderService.swift
//  Chat with AI via API Key
//
//  Created by Gan Tu on 5/7/25.
//


import Foundation
import Combine

enum AIProviderServiceError: Error, LocalizedError {
    case apiKeyMissing
    case invalidURL
    case networkError(Error)
    case apiError(String, Int?) // message, statusCode
    case streamingError(String)
    case invalidResponse
    case cancelled

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "API key is missing."
        case .invalidURL:
            return "Invalid API URL configured."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message, let statusCode):
            if let status = statusCode {
                return "API Error (\(status)): \(message)"
            } else {
                return "API Error: \(message)"
            }
        case .streamingError(let message):
            return "Streaming Error: \(message)"
        case .invalidResponse:
            return "Invalid response from API."
        case .cancelled:
            return "Request was cancelled."
        }
    }
}

// Protocol for any AI provider service
protocol AIProviderService {
    func streamChatCompletion(
        model: ModelConfig,
        messages: [Message],
        apiKey: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, AIProviderServiceError>) -> Void
    ) -> URLSessionDataTask? // Return task for cancellation
}
