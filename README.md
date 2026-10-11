# DependencyInitializer — platform differences

Swift and Kotlin use ordered sets of synchronous or asynchronous steps. The Dart implementation uses a flat list of ordinary and isolated steps, with results transferred back from separate isolates.

| Aspect | Swift | Kotlin / Android | Dart / Flutter |
|---|---|---|---|
| Implementation and usage | [swift/README.md](swift/README.md) | [kotlin/README.md](kotlin/README.md) | [dart/README.md](dart/README.md) |
| Package / namespace | `DependencyInitializer` | `io.ivangalkindeveloper.dependencyinitializer` | `dependency_initializer` |
| Runtime | iOS 13+, macOS 10.15+ | JVM library; Android integration | Native Dart VM and Flutter; isolated steps require `dart:isolate` |
| Requirements | Swift 6.0+ | JDK 17 for building; Java 8 bytecode | Dart 3.4.3+ for the library; Flutter for the bundled app |
| Process contract | Protocol with an associated container type | `DependencyInitializationProcess<T>` | `DependencyInitializationProcess<T>` |
| Pipeline definition | `StepSet(sync:)` / `StepSet(async:)` | `StepSet(sync = ...)` / `StepSet(async = ...)` | `InitializationStep` / `IsolatedInitializationStep` in a flat `steps` list |
| Ordering | Sequential sets; parallel tasks within an async set | Sequential sets; parallel coroutines within an async set | Ordinary and isolated steps are grouped by kind; no ordered-set barriers |
| Parallel work | Swift task group | Child coroutines on configurable dispatchers | Separate Dart isolates |
| Shared data | Process shared between tasks under actor isolation | Process shared between coroutines; synchronization is application-defined | Isolate-local process copies; returned values collected in `isolatedResults` |
| Container conversion | `process.toContainer` property | `process.toContainer` property | `process.toContainer(isolatedResults)` method |
| Result delivery | Success callback | Return value and success callback | Success callback and the completer supplied to `onStart` |
| Run return type | `async` returning `Void` | `suspend` returning `DIResult<P, T>?` | `Future<void>`; completion must be observed through the completer |
| Callbacks | Main actor | Main dispatcher | Calling isolate; error callback also receives `StackTrace` |
| Time representation | `Double` nanoseconds | `Double` nanoseconds | Dart `Duration`; the imported version has timing limitations |
| Repeat selection | Original sets by default; filtered `repeatStepSets` available | Original sets by default; filtered `repeatStepSets` available | Filtered `repeatSteps`; the imported `runRepeat` callback currently does not start a run |
| Cancellation | Swift task semantics; thrown step errors are handled by the initializer | Structured cancellation through the caller and child coroutines | No public cancellation handle |
| Examples | UIKit and SwiftUI | Android Compose | Flutter |

The Dart version is a separate implementation with different scheduling and completion behavior. Its ordinary async work is not awaited before isolated work starts, and it does not provide the sequencing guarantees of Swift/Kotlin step sets. Its current completion, timing, progress, and repeat limitations are documented in [dart/README.md](dart/README.md).

Swift actor isolation is checked by the compiler. Kotlin callers must synchronize shared process state explicitly. Dart isolated steps must use transferable data and return values rather than mutate the caller's process.

Each implementation's README contains only its installation, usage, examples, and current limitations.
