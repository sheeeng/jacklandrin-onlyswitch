//
//  ModelProviderService.swift
//  Modules
//
//  Created by Bo Liu on 13.12.25.
//

import Dependencies
import DependenciesMacros
import CodexKit

@DependencyClient
public struct ModelProviderService: Sendable {
    public var setAPIKey: @Sendable (ModelProvider, String, String) -> Void
    public var models: @Sendable (ModelProvider) async throws -> [ProviderModel] = { _ in [] }
    public var chat: @Sendable (ModelProvider, _ model: String, _ prompt: String) async throws -> String = { _,_,_ in "" }
    public var test: @Sendable (ModelProvider) async -> Bool = { _ in true }
    public var codexSignIn: @Sendable () async throws -> ChatGPTSession = {
        throw CodexError.uninitialized
    }
    public var codexSignOut: @Sendable () async throws -> Void = {}
    public var codexCurrentSession: @Sendable () async -> ChatGPTSession? = { nil }
}

@available(macOS 26.0, *)
extension ModelProviderService: DependencyKey {
    static public var liveValue: Self {
        let ollamaClient = OllamaLive()
        let openAIClient = OpenAILive()
        let codexClient = CodexLive()
        let geminiClient = GeminiLive()
        
        return .init { provider, apiKey, host in
            switch provider {
                case .ollama:
                    ollamaClient.setHost(host: host)
                case .openai:
                    openAIClient.setAPIToken(apiKey, host: host)
                case .codex:
                    break
                case .gemini:
                    geminiClient.setAPIKey(apiKey)
            }
        } models: { provider in
            switch provider {
                case .ollama:
                    return try await ollamaClient.models()
                case .openai:
                    return openAIClient.models()
                case .codex:
                    return codexClient.models()
                case .gemini:
                    return geminiClient.models()
            }
        } chat: { provider, model, prompt in
            switch provider {
                case .ollama:
                    return try await ollamaClient.chat(model, prompt)
                case .openai:
                    return try await openAIClient.chat(model, prompt)
                case .codex:
                    return try await codexClient.chat(model, prompt)
                case .gemini:
                    return try await geminiClient.chat(model, prompt)
            }
        } test: { provider in
            switch provider {
                case .ollama:
                    return true
                case .openai:
                    return await openAIClient.test()
                case .codex:
                    return await codexClient.test()
                case .gemini:
                    return await geminiClient.test()
            }
        } codexSignIn: {
            try await codexClient.signIn()
        } codexSignOut: {
            try await codexClient.signOut()
        } codexCurrentSession: {
            await codexClient.currentSession()
        }
    }
    
    static public var testValue: Self { Self() }
}

@available(macOS 26.0, *)
extension DependencyValues {
    public var modelProviderService: ModelProviderService {
        get { self[ModelProviderService.self] }
        set { self[ModelProviderService.self] = newValue }
    }
}
