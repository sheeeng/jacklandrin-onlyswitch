import ComposableArchitecture
import XCTest
@testable import OnlyAgent

@available(macOS 26.0, *)
@MainActor
final class PromptDialogueStreamingTests: XCTestCase {
    func testStreamingThinkingTextAndFinalScript() async {
        var initialState = PromptDialogueReducer.State(
            prompt: "Turn on dark mode",
            isAgentMode: false
        )
        initialState.currentAIModel = CurrentAIModel(provider: ModelProvider.openai.rawValue, model: "gpt-test")
        
        let store = TestStore(initialState: initialState) {
            PromptDialogueReducer()
        } withDependencies: {
            $0.promptDialogueService.requestStream = { _, _, _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(.thinkingDelta("Analyzing request..."))
                    continuation.yield(.contentDelta("tell application \"System Events\""))
                    continuation.yield(.completed(finalText: "tell application \"System Events\" to key code 144"))
                    continuation.finish()
                }
            }
            $0.promptDialogueService.request = { _, _, _, _ in "" }
        }
        
        await store.send(.sendPrompt) {
            $0.appleScript = ""
            $0.thinkingText = ""
            $0.isGenerating = true
            $0.isSuccess = nil
            $0.isMultiStepMode = false
        }
        
        await store.receive(\.receiveStreamEvent) {
            $0.thinkingText = "Analyzing request..."
        }
        
        await store.receive(\.receiveStreamEvent) {
            $0.thinkingText = "Analyzing request...tell application \"System Events\""
        }
        
        await store.receive(\.receiveStreamEvent) {
            $0.thinkingText = ""
        }
        
        await store.receive(\.generateAppleScript) {
            $0.appleScript = "tell application \"System Events\" to key code 144"
            $0.thinkingText = ""
            $0.isGenerating = false
        }
    }
    
    func testStreamingFailureClearsThinkingText() async {
        enum TestError: Error {
            case failed
        }
        
        var initialState = PromptDialogueReducer.State(
            prompt: "Turn on dark mode",
            isAgentMode: false
        )
        initialState.currentAIModel = CurrentAIModel(provider: ModelProvider.openai.rawValue, model: "gpt-test")
        initialState.thinkingText = "pending"
        
        let store = TestStore(initialState: initialState) {
            PromptDialogueReducer()
        } withDependencies: {
            $0.promptDialogueService.requestStream = { _, _, _, _ in
                throw TestError.failed
            }
            $0.promptDialogueService.request = { _, _, _, _ in "" }
        }
        
        await store.send(.sendPrompt) {
            $0.appleScript = ""
            $0.thinkingText = ""
            $0.isGenerating = true
            $0.isSuccess = nil
            $0.isMultiStepMode = false
        }
        
        await store.receive(\.generateAppleScript) {
            $0.thinkingText = ""
            $0.isGenerating = false
            $0.isSuccess = false
            $0.errorMessage = TestError.failed.localizedDescription
        }
    }
}
