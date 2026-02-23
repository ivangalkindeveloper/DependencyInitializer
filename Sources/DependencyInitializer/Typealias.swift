public typealias DIProcess = DependencyInitializationProcess

public typealias DIStep = DependencyInitializationStep

public typealias DIStepType = DependencyInitializationStepType

public typealias DIResult = DependencyInitializationResult

public typealias DIRepeatCallback<Process: DependencyInitializationProcess, T> = (
    _ createProcess: (@Sendable () -> Process)?,
    _ preSyncSteps: [SyncInitializationStep<Process>]?,
    _ asyncSteps: [AsyncInitializationStep<Process>]?,
    _ postSyncSteps: [SyncInitializationStep<Process>]?,
    _ onStart: (@Sendable () -> Void)?,
    _ onStartStep: (@Sendable (DIStep) -> Void)?,
    _ onSuccessStep: (@Sendable (DIStep, Double, Double) -> Void)?,
    _ onSuccess: (@Sendable (DIResult<Process, T>, Double) -> Void)?,
    _ onError: (@Sendable (Error, Process, DIStep, Double) -> Void)?
) async -> Void
