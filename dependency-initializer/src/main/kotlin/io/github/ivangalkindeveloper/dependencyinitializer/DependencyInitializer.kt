package io.github.ivangalkindeveloper.dependencyinitializer

import java.util.Collections
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext

/**
 * Ordered dependency assembly: sync steps on Main, concurrent async steps per set,
 * and all callbacks on Main. Runs as a child of the caller's coroutine; owns no scope.
 */
class DependencyInitializer<P : DIProcess<T>, T>(
    private val createProcess: () -> P,
    stepSets: List<StepSet<P>>,
    private val onStart: DIStartCallback? = null,
    private val onStartStep: DIStartStepCallback? = null,
    private val onSuccessStep: DISuccessStepCallback? = null,
    private val onSuccess: DISuccessCallback<P, T>? = null,
    private val onError: DIErrorCallback<P>? = null,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main.immediate,
    private val asyncDispatcher: CoroutineDispatcher = Dispatchers.Default,
    nanoTime: () -> Long = System::nanoTime,
) : TimeDispatcher(nanoTime) {
    private val stepSets = Collections.unmodifiableList(stepSets.toList())

    init { require(stepSets.isNotEmpty()) { "Step sets can't be empty" } }

    /** Returns the assembled result, or null after a reported step error. Cancellation propagates. */
    suspend fun run(): DIResult<P, T>? = withContext(mainDispatcher) {
        currentCoroutineContext().ensureActive()
        val process = createProcess()
        val startTime = nanoTime()
        val firstError = AtomicReference<Exception?>(null)
        onStart?.invoke()

        for (stepSet in stepSets) {
            currentCoroutineContext().ensureActive()
            if (firstError.get() != null) break
            if (stepSet.syncSteps != null) {
                for (step in stepSet.syncSteps) {
                    currentCoroutineContext().ensureActive()
                    val stepStart = nanoTime()
                    onStartStep?.invoke(step)
                    val error = executeStep { step.run(process) }
                    if (error != null) {
                        reportError(firstError, error, process, step, startTime)
                        break
                    }
                    currentCoroutineContext().ensureActive()
                    onSuccessStep?.invoke(step, diffTime(stepStart), diffTime(startTime))
                }
            } else {
                coroutineScope {
                    stepSet.asyncSteps!!.map { step ->
                        currentCoroutineContext().ensureActive()
                        onStartStep?.invoke(step)
                        async(step.dispatcher ?: asyncDispatcher) {
                            val stepStart = nanoTime()
                            val error = executeStep { step.run(process) }
                            currentCoroutineContext().ensureActive()
                            withContext(mainDispatcher) {
                                if (error == null) {
                                    // Already running peers may succeed even after another step failed.
                                    onSuccessStep?.invoke(step, diffTime(stepStart), diffTime(startTime))
                                } else {
                                    reportError(firstError, error, process, step, startTime)
                                }
                            }
                        }
                    }.awaitAll()
                }
            }
        }

        currentCoroutineContext().ensureActive()
        if (firstError.get() != null) return@withContext null
        val result = DependencyInitializationResult(
            container = process.toContainer,
            repeatStepSets = stepSets.mapNotNull { it.repeatable },
            repeatCallback = repeatCallback(),
        )
        onSuccess?.invoke(result, diffTime(startTime))
        result
    }

    private suspend inline fun executeStep(block: () -> Unit): Exception? = try {
        currentCoroutineContext().ensureActive()
        block()
        currentCoroutineContext().ensureActive()
        null
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (error: Exception) {
        currentCoroutineContext().ensureActive()
        error
    }

    private fun reportError(
        firstError: AtomicReference<Exception?>,
        error: Exception,
        process: P,
        step: DIStep,
        startTime: Long,
    ) {
        if (firstError.compareAndSet(null, error)) {
            onError?.invoke(error, process, step, diffTime(startTime))
        }
    }

    private fun repeatCallback(): DIRepeatCallback<P, T> = {
        createProcess, stepSets, onStart, onStartStep, onSuccessStep, onSuccess, onError ->
        DependencyInitializer(
            createProcess = createProcess ?: this.createProcess,
            stepSets = stepSets ?: this.stepSets,
            onStart = onStart ?: this.onStart,
            onStartStep = onStartStep ?: this.onStartStep,
            onSuccessStep = onSuccessStep ?: this.onSuccessStep,
            onSuccess = onSuccess ?: this.onSuccess,
            onError = onError ?: this.onError,
            mainDispatcher = mainDispatcher,
            asyncDispatcher = asyncDispatcher,
            nanoTime = nanoTime,
        ).run()
    }
}
