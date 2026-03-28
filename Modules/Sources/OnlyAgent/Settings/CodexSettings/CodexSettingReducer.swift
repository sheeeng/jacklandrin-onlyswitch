//
//  CodexSettingReducer.swift
//  Modules
//
//  Created by Codex on 28.03.26.
//

import ComposableArchitecture
import CodexKit
import Dependencies
import Foundation

@available(macOS 26.0, *)
@Reducer
public struct CodexSettingReducer {
    @ObservableState
    public struct State: Equatable {
        public var models: [String] = []
        public var isAuthorizing: Bool = false
        public var isSigningOut: Bool = false
        public var accountEmail: String? = nil
        public var plan: String? = nil
        public var authError: String? = nil
        public var isSignedIn: Bool { accountEmail != nil }

        mutating func setSession(_ session: ChatGPTSession?) {
            accountEmail = session?.account.email
            plan = session?.account.plan.rawValue.uppercased()
        }

        public init() {}
    }

    public init() {}

    @CasePathable
    public enum Action: BindableAction {
        case appear
        case getModels(TaskResult<[String]>)
        case restoreSession(TaskResult<ChatGPTSession?>)
        case signIn
        case finishSignIn(TaskResult<ChatGPTSession>)
        case signOut
        case finishSignOut(TaskResult<Void>)
        case binding(BindingAction<State>)
    }
    
    @Dependency(\.modelProviderService) var modelProviderService

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                case .appear:
                    let service = modelProviderService
                    return .run { send in
                        await send(
                            .getModels(
                                TaskResult {
                                    try await service.models(.codex).map(\.model)
                                }
                            )
                        )
                        await send(
                            .restoreSession(
                                TaskResult {
                                    await service.codexCurrentSession()
                                }
                            )
                        )
                    }

                case .signIn:
                    state.isAuthorizing = true
                    state.authError = nil
                    let service = modelProviderService
                    return .run { send in
                        await send(
                            .finishSignIn(
                                TaskResult {
                                    try await service.codexSignIn()
                                }
                            )
                        )
                    }

                case let .restoreSession(.success(session)):
                    state.setSession(session)
                    return .none

                case .restoreSession(.failure):
                    state.setSession(nil)
                    return .none

                case let .finishSignIn(.success(session)):
                    state.isAuthorizing = false
                    state.setSession(session)
                    return .none

                case let .finishSignIn(.failure(error)):
                    state.isAuthorizing = false
                    state.authError = error.localizedDescription
                    state.setSession(nil)
                    return .none

                case .signOut:
                    state.isSigningOut = true
                    state.authError = nil
                    let service = modelProviderService
                    return .run { send in
                        await send(
                            .finishSignOut(
                                TaskResult {
                                    try await service.codexSignOut()
                                }
                            )
                        )
                    }

                case .finishSignOut(.success):
                    state.isSigningOut = false
                    state.setSession(nil)
                    return .none

                case let .finishSignOut(.failure(error)):
                    state.isSigningOut = false
                    state.authError = error.localizedDescription
                    return .none

                case let .getModels(.success(models)):
                    state.models = models
                    return .none

                case .getModels(.failure):
                    return .none

                case .binding:
                    return .none
            }
        }
    }
}
