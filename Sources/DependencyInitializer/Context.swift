//
//  Context.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 04.05.2025.
//

@MainActor
final class Context<Process: DIProcess>: Sendable {
    // MARK: - Public properties
    
    let syncSteps: [SyncInitializationStep<Process>]
    let asyncSteps: [AsyncInitializationStep<Process>]
    let repeatSteps: [DIStep]
    var encounteredError: Error?
    
    // MARK: - Initialization
    
    init(
        syncSteps: [SyncInitializationStep<Process>],
        asyncSteps: [AsyncInitializationStep<Process>],
        repeatSteps: [DIStep]
    ) {
        self.syncSteps = syncSteps
        self.asyncSteps = asyncSteps
        self.repeatSteps = repeatSteps
    }
}
