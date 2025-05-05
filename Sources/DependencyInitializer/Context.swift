//
//  Context.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 04.05.2025.
//

@available(iOS 13.0, *)
@available(macOS 10.15, *)
@MainActor
class Context<Step: DependencyInitializationStep>: Sendable {
    
    init(
        repeatSteps: [Step]
    ) {
        self.repeatSteps = repeatSteps
    }
    
    let repeatSteps: [Step]
    var encounteredError: Error?
}
