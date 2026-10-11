public typealias DIProcess = DependencyInitializationProcess

public typealias DIStep = DependencyInitializationStep

public typealias DIStepType = DependencyInitializationStepType

public typealias StepSet = DependencyInitializationStepSet

public typealias DIStepSet = DependencyInitializationStepSet

public typealias DIResult = DependencyInitializationResult

public typealias DIRepeatCallback<Process: DependencyInitializationProcess, T> = (
    _ createProcess: (@Sendable () -> Process)?,
    _ stepSets: [StepSet<Process>]?,
    _ onStart: (@Sendable () -> Void)?,
    _ onStartStep: (@Sendable (DIStep) -> Void)?,
    _ onSuccessStep: (@Sendable (DIStep, Double, Double) -> Void)?,
    _ onSuccess: (@Sendable (DIResult<Process, T>, Double) -> Void)?,
    _ onError: (@Sendable (Error, Process, DIStep, Double) -> Void)?
) async -> Void
