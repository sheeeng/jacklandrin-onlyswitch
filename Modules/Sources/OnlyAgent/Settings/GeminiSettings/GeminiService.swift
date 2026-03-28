//
//  GeminiService.swift
//  Modules
//
//  Created by Bo Liu on 05.12.25.
//

import Dependencies
import DependenciesMacros
import Sharing
import Foundation
import AIProxy

final class GeminiLive: Sendable {
    @Sendable
    func setAPIKey(_ key: String) {
        @Shared(.geminiAPIKey) var apiKeyShared: String = ""
        guard !key.isEmpty else {
            return
        }
        
        $apiKeyShared.withLock { $0 = key }
    }
    
    @Sendable
    func models() -> [ProviderModel] {
        [
            "gemini-3-pro-preview",
            "gemini-3-flash-preview",
            "gemini-2.5-pro",
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite"
        ]
            .map(ProviderModel.init)
    }
    
    @Sendable
    func chat(_ model: String, _ prompt: String) async throws -> String {
        @Shared(.geminiAPIKey) var apiKeyShared: String = ""
        let apiKey: String = apiKeyShared
        
        guard !apiKey.isEmpty else {
            throw GeminiError.uninitialized
        }
        
        let systemInstruction = "You are an AppleScript expert. You generate executable AppleScript code (NOT shell scripts) for macOS automation. Always use AppleScript syntax with 'tell application' commands. Never output shell scripts or bash commands directly."
        
        let geminiService = AIProxy.geminiDirectService(unprotectedAPIKey: apiKey)
        let requestBody = GeminiGenerateContentRequestBody(
            contents: [
                .init(
                    parts: [
                        .text(prompt)
                    ],
                    role: "user"
                )
            ],
            generationConfig: .init(maxOutputTokens: 1024),
            systemInstruction: .init(
                parts: [
                    .text(systemInstruction)
                ]
            )
        )
        
        let response = try await geminiService.generateContentRequest(
            body: requestBody,
            model: model,
            secondsToWait: 120
        )

        guard let candidate = response.candidates?.first else {
            throw GeminiError.invalidResponse
        }

        guard let parts = candidate.content?.parts else {
            throw GeminiError.invalidResponse
        }

        for part in parts {
            if case let .text(text) = part {
                return text
            }
        }
        
        throw GeminiError.invalidResponse
    }
    
    @Sendable
    func test() async -> Bool {
        do {
            let _ = try await chat("gemini-2.5-pro", "Hello")
            return true
        } catch {
            return false
        }
    }
}

public enum GeminiError: Error {
    case uninitialized
    case invalidResponse
}
