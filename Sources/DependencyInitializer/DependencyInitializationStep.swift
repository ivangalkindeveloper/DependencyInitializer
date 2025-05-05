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

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public protocol DependencyInitializationStep: AnyObject, Sendable {
    associatedtype Process: DependencyInitializationProcess

    var title: String? { get }
    var type: InitializationStepType { get }
    var taskPriority: TaskPriority { get }
    var initialize: (Process) async throws -> Void { get }
}

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public final class InitializationStep<Process: DependencyInitializationProcess>: DependencyInitializationStep, Sendable {
    public typealias Process = Process
    
    // MARK: - Public properties
    
    public let title: String?
    public let taskPriority: TaskPriority
    public let type: InitializationStepType
    public let initialize: @Sendable (Process) async throws -> Void
    
    // MARK: - Initialization
    
    init(
        title: String? = nil,
        taskPriority: TaskPriority = .medium,
        type: InitializationStepType = .simple,
        initialize: @Sendable @escaping (Process) async throws -> Void
    ) {
        self.title = title
        self.taskPriority = taskPriority
        self.type = type
        self.initialize = initialize
    }
}
