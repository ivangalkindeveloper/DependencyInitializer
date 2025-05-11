//
//  Context.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 04.05.2025.
//

import Foundation

@MainActor
final class Context<Process: DIProcess>: Sendable {
    // MARK: - Public properties
    
    let process: Process
    let startTime: DispatchTime
    let steps: [InitializationStep<Process>]
    let asyncSteps: [AsyncInitializationStep<Process>]
    let repeatSteps: [DIStep]
    var error: Error?
    
    // MARK: - Initialization
    
    init(
        process: Process,
        steps: [InitializationStep<Process>],
        asyncSteps: [AsyncInitializationStep<Process>],
        repeatSteps: [DIStep]
    ) {
        self.process = process
        self.startTime = .now()
        self.steps = steps
        self.asyncSteps = asyncSteps
        self.repeatSteps = repeatSteps
    }
    
    // MARK: - Public methods
    
    func catchError(
        _ error: Error
    ) -> Void {
        guard self.error == nil else {
            return
        }
        
        self.error = error
    }
}
