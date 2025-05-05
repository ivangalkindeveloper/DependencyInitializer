//
//  DependencyInitializationProcess.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 01.05.2025.
//

@MainActor
public protocol DependencyInitializationProcess: AnyObject, Sendable {
    associatedtype T
    
    var toResult: T { get }
}
