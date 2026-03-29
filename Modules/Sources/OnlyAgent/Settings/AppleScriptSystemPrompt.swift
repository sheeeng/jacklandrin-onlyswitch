//
//  AppleScriptSystemPrompt.swift
//  Modules
//
//  Created by Codex on 29.03.26.
//

import Foundation

enum AppleScriptSystemPrompt {
    private static let baseInstruction = "You are an AppleScript expert. You generate executable AppleScript code (NOT shell scripts) for macOS automation. Always use AppleScript syntax with 'tell application' commands. Never output shell scripts or bash commands directly."

    static var withCurrentMacOSVersion: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        return "\(baseInstruction) Current macOS version: \(macOSVersion)."
    }
}
