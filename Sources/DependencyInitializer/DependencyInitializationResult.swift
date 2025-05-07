//
//  DependencyInitializationResult.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

public final class DependencyInitializationResult<Process: DependencyInitializationProcess, T> {
    // MARK: - Public properties
    
    public let result: T
    public let reinitializationStepList: [DIStep]
    public let runRepeat: DIRepeatCallback<Process, T>
    
    // MARK: - Initialization
    
    init(
        result: T,
        reinitializationStepList: [DIStep],
        runRepeat: @escaping DIRepeatCallback<Process, T>
    ) {
        self.result = result
        self.reinitializationStepList = reinitializationStepList
        self.runRepeat = runRepeat
    }
}
