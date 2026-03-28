//
//  ModelTool.swift
//  Modules
//
//  Created by Bo Liu on 06.12.25.
//

public enum ModelProvider: String, Sendable {
    case ollama
    case openai
    case codex
    case gemini
}

protocol ModelTool {
    func call(arguments: ToolArguments) async throws -> String
}

public protocol AIModel: Sendable {
    var model: String { get }
    var id: String { get }
}

struct ToolArguments {
    let prompt: String
    let model: String
}

public struct ProviderModel: Sendable {
    var model: String
    var id: String 
}

extension ProviderModel {
    init(model: String) {
        self.model = model
        self.id = model
    }
}
