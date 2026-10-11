# DependencyInitializer for Kotlin / Android

Assemble a dependency container through ordered step sets, with parallel asynchronous steps, progress callbacks, error handling, timing, and repeated initialization.

[Platform comparison](../README.md). Open this `kotlin/` directory in Android Studio and run commands from here.

## Installation

`dependency-initializer` is a JVM JAR using Kotlin Coroutines. It can be used with Android Views, Compose, or a JVM application. `sample` is a Compose app demonstrating progress, parallel loading, failure and retry, full reinitialization, and environment switching while retaining a database.

Build with JDK 17 and Gradle Wrapper 8.13. The library uses Kotlin 2.2.21, Coroutines 1.10.2, and Java 8 bytecode. The example requires Android SDK 36, Build Tools 35.0.0, and Android API 23+.

```sh
./gradlew test assembleDebug lintDebug publishToMavenLocal
```

Set the Android SDK through `ANDROID_HOME` or an ignored `local.properties` file:

```properties
sdk.dir=/absolute/path/to/Android/sdk
```

Add `mavenLocal()` to the application's repositories, alongside `google()` and `mavenCentral()`:

```kotlin
dependencies {
    implementation("io.ivangalkindeveloper:dependency-initializer:1.0.0")
}
```

Alternatively, use `includeBuild("/absolute/path/to/DependencyInitializer/kotlin")` with the same dependency coordinate. The library does not depend on Handler, Router, or Compose. `kotlinx-coroutines-android` supplies the Android main dispatcher; inject your own `mainDispatcher` outside Android. Remote Maven publishing requires separate repository and credential configuration.

## Container, process, and steps

```kotlin
import io.ivangalkindeveloper.dependencyinitializer.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

data class Dependency(val environment: String, val initialValue: String)

class InitializationProcess(val environment: String = "Production") : DIProcess<Dependency> {
    var initialValue: String? = null
    override val toContainer: Dependency
        get() = Dependency(environment, checkNotNull(initialValue))
}

val stepSets: List<StepSet<InitializationProcess>> = listOf(
    StepSet(sync = listOf(
        SyncInitializationStep(title = "Platform") { process ->
            check(process.environment.isNotBlank())
        },
    )),
    StepSet(async = listOf(
        AsyncInitializationStep(title = "Initial data", type = DIStepType.REPEATABLE) { process ->
            delay(100) // Replace this with a suspend repository call.
            val value = "Data from ${process.environment}"
            withContext(Dispatchers.Main.immediate) { process.initialValue = value }
        },
    )),
    StepSet(sync = listOf(
        SyncInitializationStep(title = "Validate", type = DIStepType.REPEATABLE) { process ->
            checkNotNull(process.initialValue)
        },
    )),
)
```

The `stepSets` list must be non-empty. Empty individual sets are allowed and skipped. Each `StepSet` accepts exactly one of `sync` or `async`.

Sets execute in order. Sync steps execute sequentially on `mainDispatcher`; async steps within one set execute concurrently on `asyncDispatcher`. Every set finishes before the next starts. Put async work that depends on earlier results into a later set.

## Android usage

`run()` is a suspend function. Use `viewModelScope`, `lifecycleScope`, or an application scope according to the desired lifetime:

```kotlin
viewModelScope.launch {
    val result = DependencyInitializer(
        createProcess = { InitializationProcess() },
        stepSets = stepSets,
        onStart = { /* Show loading. */ },
        onStartStep = { step -> /* Update progress. */ },
        onSuccessStep = { step, stepNanos, totalNanos -> /* Record timing. */ },
        onSuccess = { result, totalNanos -> /* Store result.container. */ },
        onError = { error, process, step, totalNanos -> /* Show the error. */ },
    ).run()
    // A step failure returns null; a successful result contains the container.
}
```

Process creation, sync steps, container conversion, and callbacks use `Dispatchers.Main.immediate` by default. Async steps use `Dispatchers.Default`; give a blocking step `dispatcher = Dispatchers.IO`. Inject `mainDispatcher` and `asyncDispatcher` for tests. The main dispatcher must serialize callbacks.

Async steps share the process. Move shared-field updates to the main dispatcher with `withContext`, or synchronize your model. Do not block the main dispatcher with long-running synchronous work.

## Errors and cancellation

A sync step failure stops the current set and all subsequent sets. For async failures, `onError` reports the first registered exception once; already started peers finish and successful peers still invoke `onSuccessStep`. Later sets are skipped, no container is produced, and `run()` returns `null`.

`onError` receives the original exception, process, failed step, and total time. Without a callback, a step failure still returns `null`. Retry a failed run with `initializer.run()`, which creates a fresh process each time.

Cancelling the caller cancels the run and its children. `CancellationException` propagates without invoking `onError` or `onSuccess`; cancellation of an individual async step also stops the run.

Callbacks should not throw. Exceptions from callbacks, the process factory, container conversion, and fatal JVM `Error` instances propagate to the caller. Ordinary step exceptions are delivered to `onError`. Do not run simultaneous initializations with the same mutable process.

## Reinitialization

```kotlin
val repeated = result.runRepeat() // All original sets with a fresh process.

val sandbox = result.runRepeat(
    createProcess = { InitializationProcess(environment = "Sandbox") },
    stepSets = result.repeatStepSets, // Only REPEATABLE steps.
    onSuccess = { newResult, _ -> /* Replace the container. */ },
)
```

Calling `runRepeat()` without overrides runs all original sets, including `SIMPLE`. `repeatStepSets` filters `REPEATABLE` steps while preserving order and set kind, omitting sets that become empty.

To run only repeatable work, pass `result.repeatStepSets` and a process factory seeded with dependencies required from simple steps. The sample's environment switch retains the existing database this way. Do not initialize with an empty filtered list.

Non-null overrides replace the inherited factory, sets, or callbacks. A null value inherits the previous configuration. Pass an empty lambda to disable an inherited callback. Further repeats use the configuration of the most recent successful result.

## Aliases and timing

Aliases include `DIProcess`, `DIStep`, `DIStepType`, `StepSet`, `DIStepSet`, `DIResult`, and `DIRepeatCallback`. The process type and its container type are checked by the compiler.

Durations are `Double` nanoseconds measured with a monotonic clock. Divide by `1_000_000.0` for milliseconds or `1_000_000_000.0` for seconds. Async step time includes execution and delivery to the main dispatcher, excluding time waiting for the worker to start. Total time begins after process creation and includes callbacks.

## Example and checks

Run `sample` in Android Studio. Its repository simulates data with `delay`, so it works offline. Build with `./gradlew :sample:assembleDebug`; the APK is in `sample/build/outputs/apk/debug/`.

Tests cover ordering and callbacks, concurrency and set barriers, errors and cancellation, repeats, timing, callback threads, per-step dispatchers, and protection against mutable input lists.
