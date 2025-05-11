//
//  DependencyInitializationStep.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

public protocol DependencyInitializationStep: AnyObject {
    var title: String? { get }
    var type: DIStepType { get }
}

public final class InitializationStep<Process: DIProcess>: DIStep {
    // MARK: - Public properties
    
    public let title: String?
    public let type: DIStepType
    public let run: (Process) throws -> Void
    
    // MARK: - Initialization
    
    public init(
        title: String? = nil,
        type: DIStepType = .simple,
        run: @escaping (Process) throws -> Void
    ) {
        self.title = title
        self.type = type
        self.run = run
    }
}

public final class AsyncInitializationStep<Process: DIProcess>: DIStep, Sendable {
    // MARK: - Public properties
    
    public let title: String?
    public let type: DIStepType
    public let taskPriority: TaskPriority?
    public let run: @Sendable (Process) async throws -> Void
    
    // MARK: - Initialization
    
    public init(
        title: String? = nil,
        type: DIStepType = .simple,
        taskPriority: TaskPriority? = nil,
        run: @Sendable @escaping (Process) async throws -> Void
    ) {
        self.title = title
        self.taskPriority = taskPriority
        self.type = type
        self.run = run
    }
}
