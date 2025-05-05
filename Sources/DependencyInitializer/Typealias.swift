//
//  Typealias.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 05.05.2025.
//

public typealias DIProcess = DependencyInitializationProcess

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public typealias DIStep = DependencyInitializationStep

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public typealias DIResult = DependencyInitializationResult

@available(iOS 13.0, *)
@available(macOS 10.15, *)
public typealias DIRepeatFunction<Process: DependencyInitializationProcess, Step: DependencyInitializationStep, T> = (
    _ createProcess: (() -> Process)?,
    _ steps: [Step]?,
    _ onStart: (() -> Void)?,
    _ onStartStep: ((Step) -> Void)?,
    _ onSuccessStep: ((Step, Double) -> Void)?,
    _ onSuccess: ((DIResult<Process, Step, T>, Double) -> Void)?,
    _ onError: ((Error, Process, Step, Double) -> Void)?
) async -> Void
