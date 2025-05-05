//
//  DependencyInitializationResult.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public final class DependencyInitializationResult<Process: DependencyInitializationProcess, Step: DependencyInitializationStep, T> {
    // MARK: - Public properties
    
    public let result: T
    public let reinitializationStepList: [Step]
    public let runRepeat: DIRepeatFunction<Process, Step, T>
    
    // MARK: - Initialization
    
    init(
        result: T,
        reinitializationStepList: [Step],
        runRepeat: @escaping DIRepeatFunction<Process, Step, T>
    ) {
        self.result = result
        self.reinitializationStepList = reinitializationStepList
        self.runRepeat = runRepeat
    }
}
