//
//  Typealias.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 05.05.2025.
//

public typealias DIProcess = DependencyInitializationProcess

public typealias DIStep = DependencyInitializationStep

public typealias DIResult = DependencyInitializationResult

public typealias DIRepeatCallback<Process: DependencyInitializationProcess, T> = (
    _ createProcess: (() -> Process)?,
    _ steps: [DIStep]?,
    _ onStart: (() -> Void)?,
    _ onStartStep: ((DIStep) -> Void)?,
    _ onSuccessStep: ((DIStep, Double, Double) -> Void)?,
    _ onSuccess: ((DIResult<Process, T>, Double) -> Void)?,
    _ onError: ((Error, Process, DIStep, Double) -> Void)?
) async -> Void
