public typealias DIProcess = DependencyInitializationProcess

public typealias DIStep = DependencyInitializationStep

public typealias DIStepType = DependencyInitializationStepType

public typealias DIResult = DependencyInitializationResult

public typealias DIRepeatCallback<Process: DependencyInitializationProcess, T> = (
    _ createProcess: (() -> Process)?,
    _ preSyncSteps: [SyncInitializationStep<Process>]?,
    _ asyncSteps: [AsyncInitializationStep<Process>]?,
    _ postSyncSteps: [SyncInitializationStep<Process>]?,
    _ onStart: (() -> Void)?,
    _ onStartStep: ((DIStep) -> Void)?,
    _ onSuccessStep: ((DIStep, Double, Double) -> Void)?,
    _ onSuccess: ((DIResult<Process, T>, Double) -> Void)?,
    _ onError: ((Error, Process, DIStep, Double) -> Void)?
) -> Void
