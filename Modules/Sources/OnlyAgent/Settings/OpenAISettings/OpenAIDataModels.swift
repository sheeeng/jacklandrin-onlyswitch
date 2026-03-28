//
//  OpenAIDataModels.swift
//  Modules
//
//  Created by Bo Liu on 20.11.25.
//

public struct OpenAIDataModel: AIModel {
    public var model: String
    public var id: String
    
    public init(model: String) {
        self.model = model
        self.id = model
    }
}
