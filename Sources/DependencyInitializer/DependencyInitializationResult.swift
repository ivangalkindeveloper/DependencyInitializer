//
//  DependencyInitializationResult.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

public final class DependencyInitializationResult<Process: DependencyInitializationProcess, T> {
    // MARK: - Public properties
    
    public let container: T
    public let repeatSteps: [DIStep]
    public let runRepeat: DIRepeatCallback<Process, T>
    
    // MARK: - Initialization
    
    init(
        container: T,
        reinitializationStepList: [DIStep],
        runRepeat: @escaping DIRepeatCallback<Process, T>
    ) {
        self.container = container
        self.repeatSteps = reinitializationStepList
        self.runRepeat = runRepeat
    }
}
