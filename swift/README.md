# DependencyInitializer for Swift

Build a dependency container from ordered sets of synchronous or asynchronous initialization steps. Observe progress, handle errors, record timing, and repeat initialization with a new configuration.

[Platform comparison](../README.md).

## Installation

Requires Swift 6.0+, iOS 13+ or macOS 10.15+. Add the package with Swift Package Manager:

```swift
.package(
    url: "https://github.com/ivangalkindeveloper/DependencyInitializer.git",
    from: "4.0.0"
)
```

Add the `DependencyInitializer` product to your target. Both the repository root and this `swift/` directory can be opened as a Swift package.

## Container and process

```swift
import DependencyInitializer

struct AppDependencies: Sendable {
    let environment: String
    let initialValue: String
}

@MainActor
final class InitializationProcess: DIProcess {
    typealias T = AppDependencies

    var environment = "Production"
    var initialValue: String?

    var toContainer: AppDependencies {
        AppDependencies(
            environment: environment,
            initialValue: initialValue!
        )
    }
}
```

The process conforms to `DependencyInitializationProcess`, which requires `AnyObject`, `Sendable`, and a main-actor-isolated container conversion. Its container type must be `Sendable`.

## Steps and execution

```swift
@MainActor
func initialize() async {
    let stepSets: [StepSet<InitializationProcess>] = [
        StepSet(sync: [
            SyncInitializationStep<InitializationProcess>(
                title: "Platform",
                run: { process in
                    process.environment = "Production"
                }
            ),
        ]),
        StepSet(async: [
            AsyncInitializationStep<InitializationProcess>(
                title: "Initial data",
                type: .repeatable,
                run: { process in
                    try await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        process.initialValue = "Loaded"
                    }
                }
            ),
        ]),
    ]

    await DependencyInitializer<InitializationProcess, AppDependencies>(
        createProcess: { InitializationProcess() },
        stepSets: stepSets,
        onStart: { /* Show loading. */ },
        onStartStep: { step in /* Update progress. */ },
        onSuccessStep: { step, stepNanos, totalNanos in /* Record timing. */ },
        onSuccess: { result, totalNanos in
            print(result.container.initialValue)
        },
        onError: { error, process, step, totalNanos in
            print(error)
        }
    ).run()
}
```

The step-set list must be non-empty. Each set contains either sync or async steps. Sync steps execute sequentially on the main actor. Async steps in a set execute concurrently in a task group; the next set starts only after the current one finishes.

Use a later set for work that depends on results from earlier async steps. Access shared process state through actor isolation. Avoid blocking the main actor in sync steps. Async steps accept an optional `taskPriority`.

All callbacks are delivered on the main actor. Times are `Double` nanoseconds measured with monotonic clocks; divide by `1_000_000` for milliseconds.

## Errors

A sync failure stops the remaining work. An async failure is reported once, already launched peers finish, and later sets are skipped. Successful peers can still invoke their success callbacks. A failed run does not produce a container or invoke `onSuccess`.

The error callback receives the original error, partially populated process, failed step, and total duration. Errors thrown by cancellation are handled as step errors. Retry by running the initializer again with a fresh process.

## Reinitialization

A successful `DIResult` contains `container`, `repeatStepSets`, and an async `runRepeat` closure. Calling that closure with all overrides set to `nil` uses the original configuration, including all original step sets.

```swift
await result.runRepeat(nil, nil, nil, nil, nil, nil, nil)
```

Arguments are positional, in this order: `createProcess`, `stepSets`, `onStart`, `onStartStep`, `onSuccessStep`, `onSuccess`, `onError`.

To execute only repeatable steps, pass the filtered sets and a process factory seeded with any dependencies those steps require:

```swift
await result.runRepeat(
    { makeSeededProcess() },
    result.repeatStepSets,
    nil, nil, nil, nil, nil
)
```

`makeSeededProcess()` is your application-defined factory. Do not pass an empty filtered list. A `nil` override inherits the earlier value; an empty callback can disable inherited behavior.

## Checks and examples

From this directory:

```sh
swift test
```

Tests cover ordered and parallel work, errors, callbacks, and reinitialization.

The original UIKit and SwiftUI apps in `Example/` have valid local package references but still use the removed `InitializationStep` API. They currently require migration to `StepSet`, `SyncInitializationStep`, and `AsyncInitializationStep` before they can build. The library and its tests build independently.
