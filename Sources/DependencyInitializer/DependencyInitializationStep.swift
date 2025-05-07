//
//  DependencyInitializationStep.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

import Foundation

public enum InitializationStepType: Sendable {
    case simple, repeatable;
}

public protocol DependencyInitializationStep: AnyObject {
    var title: String? { get }
    var type: InitializationStepType { get }
}

public final class SyncInitializationStep<Process: DIProcess>: DependencyInitializationStep {
    // MARK: - Public properties
    
    public let title: String?
    public let type: InitializationStepType
    public let run: (Process) throws -> Void
    
    // MARK: - Initialization
    
    public init(
        title: String? = nil,
        type: InitializationStepType = .simple,
        run: @escaping (Process) throws -> Void
    ) {
        self.title = title
        self.type = type
        self.run = run
    }
}

public final class AsyncInitializationStep<Process: DIProcess>: DependencyInitializationStep, Sendable {
    // MARK: - Public properties
    
    public let title: String?
    public let type: InitializationStepType
    public let taskPriority: TaskPriority?
    public let run: @Sendable (Process) async throws -> Void
    
    // MARK: - Initialization
    
    public init(
        title: String? = nil,
        type: InitializationStepType = .simple,
        taskPriority: TaskPriority? = nil,
        run: @Sendable @escaping (Process) async throws -> Void
    ) {
        self.title = title
        self.taskPriority = taskPriority
        self.type = type
        self.run = run
    }
}
