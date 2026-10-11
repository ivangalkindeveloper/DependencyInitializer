package io.github.ivangalkindeveloper.dependencyinitializer

import java.util.Collections

class DependencyInitializationResult<P : DIProcess<T>, T> internal constructor(
    val container: T,
    repeatStepSets: List<StepSet<P>>,
    private val repeatCallback: DIRepeatCallback<P, T>,
) {
    val repeatStepSets: List<StepSet<P>> = Collections.unmodifiableList(repeatStepSets.toList())

    /**
     * Null parameters inherit the previous initializer's configuration, as in Swift.
     * By default this runs ALL original sets with a newly created process.
     * To run only repeatable steps, explicitly supply [repeatStepSets] and a seeded process.
     */
    suspend fun runRepeat(
        createProcess: (() -> P)? = null,
        stepSets: List<StepSet<P>>? = null,
        onStart: DIStartCallback? = null,
        onStartStep: DIStartStepCallback? = null,
        onSuccessStep: DISuccessStepCallback? = null,
        onSuccess: DISuccessCallback<P, T>? = null,
        onError: DIErrorCallback<P>? = null,
    ): DIResult<P, T>? = repeatCallback(createProcess, stepSets, onStart, onStartStep, onSuccessStep, onSuccess, onError)
}
