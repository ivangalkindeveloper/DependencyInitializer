package io.github.ivangalkindeveloper.dependencyinitializer

typealias DIProcess<T> = DependencyInitializationProcess<T>
typealias DIStep = DependencyInitializationStep
typealias DIStepType = DependencyInitializationStepType
typealias StepSet<P> = DependencyInitializationStepSet<P>
typealias DIStepSet<P> = DependencyInitializationStepSet<P>
typealias DIResult<P, T> = DependencyInitializationResult<P, T>

typealias DIStartCallback = () -> Unit
typealias DIStartStepCallback = (step: DIStep) -> Unit
typealias DISuccessStepCallback = (step: DIStep, stepDurationNanos: Double, totalDurationNanos: Double) -> Unit
typealias DISuccessCallback<P, T> = (result: DIResult<P, T>, totalDurationNanos: Double) -> Unit
typealias DIErrorCallback<P> = (error: Throwable, process: P, step: DIStep, totalDurationNanos: Double) -> Unit
typealias DIRepeatCallback<P, T> = suspend (
    createProcess: (() -> P)?,
    stepSets: List<StepSet<P>>?,
    onStart: DIStartCallback?,
    onStartStep: DIStartStepCallback?,
    onSuccessStep: DISuccessStepCallback?,
    onSuccess: DISuccessCallback<P, T>?,
    onError: DIErrorCallback<P>?,
) -> DIResult<P, T>?
