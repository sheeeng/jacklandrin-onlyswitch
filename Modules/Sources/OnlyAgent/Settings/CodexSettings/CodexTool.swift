//
//  CodexTool.swift
//  Modules
//
//  Created by Codex on 28.03.26.
//

import Dependencies
import Foundation
import OSLog

@available(macOS 26.0, *)
final class CodexTool: ModelTool {
    func call(arguments: ToolArguments) async throws -> String {
        @Dependency(\.modelProviderService) var modelProviderService
        Logger.onlyAgentDebug.log("[Codex] model: \(arguments.model)\n prompt: \(arguments.prompt)")

        let message = try await modelProviderService.chat(.codex, arguments.model, arguments.prompt)
        Logger.onlyAgentDebug.log("[Codex] \(message)")
        return message
    }
}
