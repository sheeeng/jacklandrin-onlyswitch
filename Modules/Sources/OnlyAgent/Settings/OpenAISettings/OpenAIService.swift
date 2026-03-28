//
//  OpenAIService.swift
//  Modules
//
//  Created by Bo Liu on 20.11.25.
//

import Dependencies
import DependenciesMacros
import AIProxy
import Foundation
import Sharing

public enum OpenAIError: Error {
    case uninitialized
}

final class OpenAILive: Sendable {
    @Sendable
    func setAPIToken(_ apiToken: String, host: String = "api.openai.com") {
        @Shared(.openAIAPIKey) var apiKeyShared: String = ""
        @Shared(.openAIHost) var hostShared
        guard !apiToken.isEmpty else {
            return
        }
        $apiKeyShared.withLock { $0 = apiToken }
        $hostShared.withLock { $0 = host }
    }
    
    @Sendable
    func models() -> [ProviderModel] {
        [
            "gpt-5.4",
            "gpt-5.2",
            "gpt-5-mini",
            "gpt-5-nano",
            "gpt-4.1",
            "gpt-4.1-mini"
        ]
        .map(ProviderModel.init)
    }
    
    @Sendable
    func chat(_ model: String, _ prompt: String) async throws -> String {
        @Shared(.openAIAPIKey) var apiKeyShared: String = ""
        @Shared(.openAIHost) var hostShared
        let apiKey: String = apiKeyShared
        let host: String = hostShared
        
        guard !apiKey.isEmpty else {
            throw OpenAIError.uninitialized
        }
        
        let baseURL: String? = {
            guard !host.isEmpty else { return nil }
            if host.hasPrefix("http://") || host.hasPrefix("https://") {
                return host
            }
            return "https://\(host)"
        }()
        let requestFormat: OpenAIRequestFormat = {
            guard let baseURL else { return .standard }
            if baseURL.contains("/v1") {
                return .noVersionPrefix
            }
            return .standard
        }()
        let openAIService = AIProxy.openAIDirectService(
            unprotectedAPIKey: apiKey,
            baseURL: baseURL,
            requestFormat: requestFormat
        )
        let result = try await openAIService.chatCompletionRequest(
            body: .init(
                model: model,
                messages: [
                    .system(content: .text("You are an AppleScript expert. You generate executable AppleScript code (NOT shell scripts) for macOS automation. Always use AppleScript syntax with 'tell application' commands. Never output shell scripts or bash commands directly.")),
                    .user(content: .text(prompt))
                ]
            ),
            secondsToWait: 120
        )
        
        return result.choices.first?.message.content ?? ""
    }
    
    @Sendable
    func test() async -> Bool {
        do {
            let _ = try await chat("gpt-4.1-mini", "Hello")
            return true
        } catch {
            return false
        }
    }
}
