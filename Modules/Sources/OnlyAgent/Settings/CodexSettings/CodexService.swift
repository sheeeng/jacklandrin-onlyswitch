//
//  CodexService.swift
//  Modules
//
//  Created by Codex on 28.03.26.
//

import CodexKit
import Dependencies
import DependenciesMacros
import Foundation
#if canImport(AppKit)
import AppKit
#endif

public enum CodexError: Error {
    case uninitialized
}

final class CodexLive: Sendable {
    @Sendable
    func models() -> [ProviderModel] {
        [
            "codex-mini-latest",
            "gpt-5.3-codex",
            "gpt-5.2-codex",
            "gpt-5.1-codex-max",
            "gpt-5.1-codex-mini"
        ]
        .map(ProviderModel.init)
    }

    @Sendable
    func signIn() async throws -> ChatGPTSession {
        await prepareForInteractiveSignIn()
        return try await signInOnMainActor()
    }

    @Sendable
    func signOut() async throws {
        try await codexRuntimePool.signOut()
    }

    @Sendable
    func currentSession() async -> ChatGPTSession? {
        await codexRuntimePool.currentSession()
    }

    @Sendable
    func chat(_ model: String, _ prompt: String) async throws -> String {
        try await codexRuntimePool.chat(model: model, prompt: prompt)
    }

    @Sendable
    func test() async -> Bool {
        await currentSession() != nil
    }

    @MainActor
    private func signInOnMainActor() async throws -> ChatGPTSession {
        try await codexRuntimePool.signIn()
    }

    @MainActor
    private func prepareForInteractiveSignIn() {
#if canImport(AppKit)
        NSApp.activate(ignoringOtherApps: true)
#endif
    }
}

private actor CodexRuntimePool {
    private struct RuntimeEntry {
        let runtime: AgentRuntime
        var restored: Bool
        var threadID: String?
    }

    private var runtimes: [String: RuntimeEntry] = [:]

    private let defaultModel = "codex-mini-latest"
    private let secureStoreService = "OnlySwitch.Codex.ChatGPTSession"
    private let secureStoreAccount = "main"

    func signIn() async throws -> ChatGPTSession {
        let runtime = try ensureRuntime(for: defaultModel)
        try await ensureRestored(for: defaultModel)
        return try await runtime.signIn()
    }

    func signOut() async throws {
        let modelKeys = Array(runtimes.keys)
        for model in modelKeys {
            guard let entry = runtimes[model] else { continue }
            try await entry.runtime.signOut()
            runtimes[model]?.threadID = nil
        }
        if modelKeys.isEmpty {
            let runtime = try ensureRuntime(for: defaultModel)
            try await ensureRestored(for: defaultModel)
            try await runtime.signOut()
        }
    }

    func currentSession() async -> ChatGPTSession? {
        do {
            _ = try ensureRuntime(for: defaultModel)
            try await ensureRestored(for: defaultModel)
            return await runtimes[defaultModel]?.runtime.currentSession()
        } catch {
            return nil
        }
    }

    func chat(model: String, prompt: String) async throws -> String {
        let runtime = try ensureRuntime(for: model)
        try await ensureRestored(for: model)
        guard let session = await runtime.currentSession(), !session.accessToken.isEmpty else {
            throw CodexError.uninitialized
        }

        let threadID: String
        if let existingThreadID = runtimes[model]?.threadID {
            threadID = existingThreadID
        } else {
            let thread = try await runtime.createThread(title: "OnlyAgent")
            threadID = thread.id
            runtimes[model]?.threadID = threadID
        }

        let userPrompt = UserMessageRequest(text: prompt)
        return try await runtime.sendMessage(userPrompt, in: threadID)
    }

    private func ensureRuntime(for model: String) throws -> AgentRuntime {
        if let entry = runtimes[model] {
            return entry.runtime
        }

        let authProvider = try ChatGPTAuthProvider(method: .oauth)
        let secureStore = KeychainSessionSecureStore(
            service: secureStoreService,
            account: secureStoreAccount
        )
        let backend = CodexResponsesBackend(
            configuration: .init(
                model: model,
                reasoningEffort: .medium,
                enableWebSearch: false
            )
        )
        let stateStore = try GRDBRuntimeStateStore(
            url: runtimeStateURL(for: model)
        )
        let runtime = try AgentRuntime(configuration: .init(
            authProvider: authProvider,
            secureStore: secureStore,
            backend: backend,
            approvalPresenter: AutoApprovePresenter(),
            stateStore: stateStore
        ))
        runtimes[model] = .init(runtime: runtime, restored: false, threadID: nil)
        return runtime
    }

    private func ensureRestored(for model: String) async throws {
        guard var entry = runtimes[model] else { return }
        guard !entry.restored else { return }
        _ = try await entry.runtime.restore()
        entry.restored = true
        runtimes[model] = entry
    }

    private func runtimeStateURL(for model: String) -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "jacklandrin.OnlySwitch"
        let sanitizedModel = model.replacingOccurrences(
            of: "[^a-zA-Z0-9\\-_.]",
            with: "_",
            options: .regularExpression
        )
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appending(path: bundleID)
            .appending(path: "CodexRuntime")
            .appending(path: "\(sanitizedModel).sqlite")
    }
}

private struct AutoApprovePresenter: ApprovalPresenting {
    func requestApproval(_ request: ApprovalRequest) async throws -> ApprovalDecision {
        _ = request
        return .approved
    }
}

private let codexRuntimePool = CodexRuntimePool()
