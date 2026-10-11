package io.github.ivangalkindeveloper.dependencyinitializer

import java.util.concurrent.Executors
import kotlin.test.*
import kotlinx.coroutines.*
import kotlinx.coroutines.test.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DependencyInitializerTest {
    data class Container(val values: Map<String, String>)
    class Process(seed: Map<String, String> = emptyMap()) : DIProcess<Container> {
        val values = seed.toMutableMap()
        var containerReads = 0
        override val toContainer: Container
            get() { containerReads++; return Container(values.toMap()) }
    }

    @Test fun syncStepsPreserveOrderingAndCallbackSequence() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val events = mutableListOf<String>()
        val process = Process()
        val sets = listOf(StepSet(sync = listOf(
            SyncInitializationStep<Process>(title = "environment") { it.values["environment"] = "dev" },
            SyncInitializationStep<Process>(title = "repository") { it.values["repository"] = checkNotNull(it.values["environment"]) + "-repo" },
        )))
        val result = DependencyInitializer(
            createProcess = { process }, stepSets = sets,
            onStart = { events += "start" },
            onStartStep = { events += "start:${it.title}" },
            onSuccessStep = { step, _, _ -> events += "done:${step.title}" },
            onSuccess = { _, _ -> events += "success" },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()
        assertEquals("dev-repo", result!!.container.values["repository"])
        assertEquals(listOf("start", "start:environment", "done:environment", "start:repository", "done:repository", "success"), events)
        assertEquals(1, process.containerReads)
    }

    @Test fun asyncStepsOverlapAndNextSetWaitsForEveryStep() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val firstStarted = CompletableDeferred<Unit>()
        val secondStarted = CompletableDeferred<Unit>()
        val release = CompletableDeferred<Unit>()
        var postStarted = false
        val initializer = DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(
                StepSet(async = listOf(
                    AsyncInitializationStep<Process> { process ->
                        firstStarted.complete(Unit); release.await()
                        withContext(dispatcher) { process.values["a"] = "first" }
                    },
                    AsyncInitializationStep<Process> { process ->
                        secondStarted.complete(Unit); release.await(); delay(10)
                        withContext(dispatcher) { process.values["b"] = "second" }
                    },
                )),
                StepSet(sync = listOf(SyncInitializationStep<Process> {
                    assertEquals(setOf("a", "b"), it.values.keys); postStarted = true
                })),
            ),
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        )
        val result = async { initializer.run() }
        runCurrent()
        assertTrue(firstStarted.isCompleted)
        assertTrue(secondStarted.isCompleted)
        assertFalse(postStarted)
        release.complete(Unit)
        assertNotNull(result.await())
        assertTrue(postStarted)
    }

    @Test fun sequentialAsyncSetsCanReadEarlierResults() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val result = DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(
                StepSet(async = listOf(AsyncInitializationStep<Process> { delay(10); it.values["first"] = "one" })),
                StepSet(async = listOf(AsyncInitializationStep<Process> { it.values["second"] = checkNotNull(it.values["first"]) + "-two" })),
            ), mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()
        assertEquals("one-two", result!!.container.values["second"])
    }

    @Test fun syncErrorStopsRemainingStepsAndSetsWithoutBuildingContainer() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val process = Process()
        val error = IllegalStateException("sync failure")
        val failing = SyncInitializationStep<Process>(title = "failure") { throw error }
        var errors = 0
        val result = DependencyInitializer(
            createProcess = { process },
            stepSets = listOf(
                StepSet(sync = listOf(failing, SyncInitializationStep { fail("Must not run") })),
                StepSet(async = listOf(AsyncInitializationStep<Process> { fail("Must not start next set") })),
            ),
            onError = { actual, actualProcess, step, duration ->
                errors++; assertSame(error, actual); assertSame(process, actualProcess); assertSame(failing, step); assertTrue(duration >= 0)
            }, onSuccess = { _, _ -> fail("Must not succeed") },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()
        assertNull(result)
        assertEquals(1, errors)
        assertEquals(0, process.containerReads)
    }

    @Test fun parallelErrorsReportOnlyFirstAndWaitForSuccessfulPeer() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val process = Process()
        val firstError = IllegalStateException("first")
        val firstStep = AsyncInitializationStep<Process>(title = "first") { delay(5); throw firstError }
        val events = mutableListOf<String>()
        val result = DependencyInitializer(
            createProcess = { process },
            stepSets = listOf(
                StepSet(async = listOf(
                    firstStep,
                    AsyncInitializationStep(title = "second") { delay(10); error("second") },
                    AsyncInitializationStep(title = "peer") { delay(20); it.values["peer"] = "completed" },
                )),
                StepSet(sync = listOf(SyncInitializationStep<Process> { fail("Next set must not run") })),
            ),
            onError = { actual, _, step, _ -> assertSame(firstError, actual); assertSame(firstStep, step); events += "error" },
            onSuccessStep = { step, _, _ -> events += "success:${step.title}" },
            onSuccess = { _, _ -> fail("Must not succeed") },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()
        assertNull(result)
        assertEquals(listOf("error", "success:peer"), events)
        assertEquals("completed", process.values["peer"])
        assertEquals(0, process.containerReads)
    }

    @Test fun repeatMetadataFiltersStepsPreservingSetOrderAndKind() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val first = SyncInitializationStep<Process>(title = "repeat-sync", type = DIStepType.REPEATABLE) { }
        val second = AsyncInitializationStep<Process>(title = "repeat-async", type = DIStepType.REPEATABLE) { }
        val result = DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(
                StepSet(sync = listOf(SyncInitializationStep { }, first)),
                StepSet(async = listOf(AsyncInitializationStep<Process> { })),
                StepSet(async = listOf(second, AsyncInitializationStep { })),
            ), mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()!!
        assertEquals(2, result.repeatStepSets.size)
        assertFalse(result.repeatStepSets[0].isAsync)
        assertTrue(result.repeatStepSets[1].isAsync)
        assertSame(first, result.repeatStepSets[0].steps.single())
        assertSame(second, result.repeatStepSets[1].steps.single())
    }

    @Test fun defaultRepeatRunsAllOriginalSetsWithFreshProcessAndInheritedCallbacks() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        var created = 0
        var simpleRuns = 0
        var repeatRuns = 0
        var successes = 0
        val result = DependencyInitializer(
            createProcess = { created++; Process() },
            stepSets = listOf(StepSet(sync = listOf(
                SyncInitializationStep<Process> { simpleRuns++; it.values["simple"] = "$simpleRuns" },
                SyncInitializationStep(type = DIStepType.REPEATABLE) { repeatRuns++; it.values["repeat"] = "$repeatRuns" },
            ))),
            onSuccess = { _, _ -> successes++ }, mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()!!
        val repeated = result.runRepeat()!!
        assertEquals(2, created)
        assertEquals(2, simpleRuns)
        assertEquals(2, repeatRuns)
        assertEquals(2, successes)
        assertEquals("1", result.container.values["repeat"])
        assertEquals("2", repeated.container.values["repeat"])
    }

    @Test fun repeatableOnlySupportsSeededProcessAndCallbackOverrides() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        var simpleRuns = 0
        var inheritedSuccesses = 0
        var overriddenSuccesses = 0
        val result = DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(StepSet(sync = listOf(
                SyncInitializationStep<Process> { simpleRuns++; it.values["database"] = "original" },
                SyncInitializationStep(type = DIStepType.REPEATABLE) { it.values["repository"] = checkNotNull(it.values["database"]) + "-repo" },
            ))),
            onSuccess = { _, _ -> inheritedSuccesses++ }, mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        ).run()!!
        val repeated = result.runRepeat(
            createProcess = { Process(mapOf("database" to "seeded")) }, stepSets = result.repeatStepSets,
            onSuccess = { _, _ -> overriddenSuccesses++ },
        )!!
        assertEquals(1, simpleRuns)
        assertEquals(1, inheritedSuccesses)
        assertEquals(1, overriddenSuccesses)
        assertEquals("seeded-repo", repeated.container.values["repository"])
    }

    @Test fun failedRunCanBeRetriedOnSameInitializerWithNewProcess() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        var attempts = 0
        var errors = 0
        val initializer = DependencyInitializer(
            createProcess = { Process(mapOf("attempt" to "${++attempts}")) },
            stepSets = listOf(StepSet(sync = listOf(SyncInitializationStep<Process> { check(it.values["attempt"] != "1") }))),
            onError = { _, _, _, _ -> errors++ }, mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        )
        assertNull(initializer.run())
        assertEquals("2", initializer.run()!!.container.values["attempt"])
        assertEquals(1, errors)
    }

    @Test fun cancellationCancelsAllChildrenWithoutReportingStepErrorOrSuccess() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val process = Process()
        var finalized = 0
        val initializer = DependencyInitializer(
            createProcess = { process },
            stepSets = listOf(StepSet(async = List(2) {
                AsyncInitializationStep<Process> { try { awaitCancellation() } finally { finalized++ } }
            })),
            onError = { _, _, _, _ -> fail("Cancellation must not be reported as an error") },
            onSuccessStep = { _, _, _ -> fail("Cancelled steps must not succeed") },
            onSuccess = { _, _ -> fail("Cancelled run must not succeed") },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        )
        val job = launch { initializer.run() }
        runCurrent()
        job.cancelAndJoin()
        assertEquals(2, finalized)
        assertEquals(0, process.containerReads)
    }

    @Test fun childCancellationPropagatesAndCancelsPeers() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        var finalized = false
        val initializer = DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(StepSet(async = listOf(
                AsyncInitializationStep<Process> { delay(1); throw CancellationException("cancelled step") },
                AsyncInitializationStep { try { awaitCancellation() } finally { finalized = true } },
            ))),
            onError = { _, _, _, _ -> fail("Cancellation is not an error") },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
        )
        assertFailsWith<CancellationException> { initializer.run() }
        assertTrue(finalized)
    }

    @Test fun cancellingDuringStartCallbackDoesNotExecuteSyncStep() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        lateinit var job: Job
        val process = Process()
        val initializer = DependencyInitializer(
            createProcess = { process },
            stepSets = listOf(StepSet(sync = listOf(SyncInitializationStep<Process> { fail("Step must not start after cancellation") }))),
            onStartStep = { job.cancel() }, onError = { _, _, _, _ -> fail("Cancellation is not an error") },
            mainDispatcher = dispatcher,
        )
        job = launch { initializer.run() }
        job.join()
        assertTrue(job.isCancelled)
        assertEquals(0, process.containerReads)
    }

    @Test fun timeMetricsAreMonotonicNanoseconds() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        var stepDuration = -1.0
        var totalDuration = -1.0
        DependencyInitializer(
            createProcess = { Process() },
            stepSets = listOf(StepSet(async = listOf(AsyncInitializationStep<Process> { delay(25) }))),
            onSuccessStep = { _, duration, total -> stepDuration = duration; assertEquals(25_000_000.0, total) },
            onSuccess = { _, duration -> totalDuration = duration },
            mainDispatcher = dispatcher, asyncDispatcher = dispatcher,
            nanoTime = { testScheduler.currentTime * 1_000_000 },
        ).run()
        assertEquals(25_000_000.0, stepDuration)
        assertEquals(25_000_000.0, totalDuration)
    }

    @Test fun syncStepsFactoriesAndCallbacksUseMainAndAsyncDispatcherCanBeOverridden() = runBlocking {
        Executors.newSingleThreadExecutor { Thread(it, "di-main") }.asCoroutineDispatcher().use { main ->
            Executors.newSingleThreadExecutor { Thread(it, "di-worker") }.asCoroutineDispatcher().use { worker ->
                Executors.newSingleThreadExecutor { Thread(it, "di-special") }.asCoroutineDispatcher().use { special ->
                    fun thread() = Thread.currentThread().name.substringBefore(" @")
                    val callbackThreads = mutableListOf<String>()
                    var factoryThread = ""
                    var syncThread = ""
                    var asyncThread = ""
                    var overrideThread = ""
                    val initializer = DependencyInitializer(
                        createProcess = { factoryThread = thread(); Process() },
                        stepSets = listOf(
                            StepSet(sync = listOf(SyncInitializationStep<Process> { syncThread = thread() })),
                            StepSet(async = listOf(
                                AsyncInitializationStep<Process> { asyncThread = thread() },
                                AsyncInitializationStep(dispatcher = special) { overrideThread = thread() },
                            )),
                        ),
                        onStart = { callbackThreads += thread() }, onStartStep = { callbackThreads += thread() },
                        onSuccessStep = { _, _, _ -> callbackThreads += thread() }, onSuccess = { _, _ -> callbackThreads += thread() },
                        mainDispatcher = main, asyncDispatcher = worker,
                    )
                    assertNotNull(initializer.run())
                    assertEquals("di-main", factoryThread)
                    assertEquals("di-main", syncThread)
                    assertEquals("di-worker", asyncThread)
                    assertEquals("di-special", overrideThread)
                    assertEquals(8, callbackThreads.size)
                    assertTrue(callbackThreads.all { it == "di-main" })
                    var errorThread = ""
                    val result = DependencyInitializer(
                        createProcess = { Process() },
                        stepSets = listOf(StepSet(async = listOf(AsyncInitializationStep<Process> { error("failure") }))),
                        onError = { _, _, _, _ -> errorThread = thread() }, mainDispatcher = main, asyncDispatcher = worker,
                    ).run()
                    assertNull(result)
                    assertEquals("di-main", errorThread)
                }
            }
        }
    }

    @Test fun stepSetsAndRepeatMetadataAreDetachedAndImmutable() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val steps = mutableListOf(SyncInitializationStep<Process>(type = DIStepType.REPEATABLE) { it.values["key"] = "value" })
        val set = StepSet(sync = steps)
        val sets = mutableListOf(set)
        val initializer = DependencyInitializer(createProcess = { Process() }, stepSets = sets, mainDispatcher = dispatcher, asyncDispatcher = dispatcher)
        steps.clear(); sets.clear()
        val result = initializer.run()!!
        assertEquals("value", result.container.values["key"])
        assertFailsWith<UnsupportedOperationException> { (set.steps as MutableList).clear() }
        assertFailsWith<UnsupportedOperationException> { (result.repeatStepSets as MutableList).clear() }
    }

    @Test fun validatesSetsButAllowsEmptyIndividualSet() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        assertFailsWith<IllegalArgumentException> { StepSet<Process>() }
        assertFailsWith<IllegalArgumentException> { StepSet<Process>(sync = emptyList(), async = emptyList()) }
        assertFailsWith<IllegalArgumentException> { DependencyInitializer(createProcess = { Process() }, stepSets = emptyList(), mainDispatcher = dispatcher) }
        val result = DependencyInitializer(createProcess = { Process() }, stepSets = listOf(StepSet(sync = emptyList())), mainDispatcher = dispatcher).run()!!
        assertTrue(result.container.values.isEmpty())
        assertTrue(result.repeatStepSets.isEmpty())
    }

    @Test fun callbackFailuresPropagateAndAreNotReportedAsStepErrors() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val failure = IllegalStateException("callback failure")
        val initializer = DependencyInitializer(
            createProcess = { Process() }, stepSets = listOf(StepSet(sync = listOf(SyncInitializationStep<Process> { }))),
            onSuccessStep = { _, _, _ -> throw failure }, onError = { _, _, _, _ -> fail("Callback is not a step error") },
            mainDispatcher = dispatcher,
        )
        assertEquals(failure.message, assertFailsWith<IllegalStateException> { initializer.run() }.message)
    }

    @Test fun factoryAndContainerFailuresPropagate() = runTest {
        val dispatcher = StandardTestDispatcher(testScheduler)
        val factoryError = IllegalStateException("factory failed")
        val factory = DependencyInitializer<Process, Container>(
            createProcess = { throw factoryError }, stepSets = listOf(StepSet(sync = emptyList())), mainDispatcher = dispatcher,
        )
        assertEquals(factoryError.message, assertFailsWith<IllegalStateException> { factory.run() }.message)
        val containerError = IllegalStateException("container failed")
        val process = object : DIProcess<String> { override val toContainer: String get() = throw containerError }
        val container = DependencyInitializer(createProcess = { process }, stepSets = listOf(StepSet(sync = emptyList())), mainDispatcher = dispatcher)
        assertEquals(containerError.message, assertFailsWith<IllegalStateException> { container.run() }.message)
    }
}
