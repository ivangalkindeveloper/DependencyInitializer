# dependency_initializer for Dart / Flutter

Create a dependency container through ordinary initialization steps and steps running in separate isolates. The package supports callbacks, isolated result collection, and a result object containing repeat-step configuration.

[Platform comparison](../README.md).

## Installation

The library requires Dart 3.4.3+ and has no Flutter SDK dependency. Isolated steps require a native Dart VM with `dart:isolate`; this execution path is not supported on the web. See the [Dart isolate documentation](https://dart.dev/language/isolates).

```yaml
dependencies:
  dependency_initializer:
    git:
      url: https://github.com/ivangalkindeveloper/DependencyInitializer.git
      ref: master
      path: dart
```

For a local checkout:

```yaml
dependencies:
  dependency_initializer:
    path: /absolute/path/to/DependencyInitializer/dart
```

Run `flutter pub get` in a Flutter application or `dart pub get` in a Dart application.

## Container, process, and steps

```dart
import 'dart:async';
import 'package:dependency_initializer/dependency_initializer.dart';

class AppDependencies {
  AppDependencies(this.environment, this.initialValue);
  final String environment;
  final String initialValue;
}

class AppProcess extends DIProcess<AppDependencies> {
  String environment = 'Production';

  @override
  AppDependencies toContainer(Map<dynamic, dynamic> isolatedResults) =>
      AppDependencies(environment, isolatedResults['initialValue'] as String);
}

Future<void> main() async {
  late Future<DIResult<AppProcess, AppDependencies>> completed;

  final initializer = DependencyInitializer<AppProcess, AppDependencies>(
    createProcess: () => AppProcess(),
    steps: [
      InitializationStep<AppProcess, AppDependencies>(
        title: 'Environment',
        run: (process) { process.environment = 'Production'; },
      ),
      IsolatedInitializationStep<AppProcess, AppDependencies, String, String>(
        title: 'Initial value',
        type: DIStepType.repeatable,
        isolatedKey: 'initialValue',
        run: (process) => 'Data for ${process.environment}',
      ),
    ],
    onStart: (completer) { completed = completer.future; },
    onError: (error, stackTrace, process, step, duration) {
      print('Initialization failed: $error');
    },
  );

  final launch = initializer.run();
  await Future.wait<void>([
    launch,
    completed.then<void>((result) {
      print(result.container.initialValue);
    }),
  ]);
}
```

The `onStart` completer is assigned synchronously when the run starts. Observe its future, including errors, to know when container construction actually finishes. The `run()` future alone is not a reliable completion signal for ordinary async steps in the current version.

`InitializationStep` accepts a synchronous or asynchronous function executed in the calling isolate. `IsolatedInitializationStep` accepts an operation executed in a new isolate and stores its returned value under `isolatedKey`. `toContainer` combines fields from the calling process with the returned map.

Pass only transferable process state, closures, and results to isolated steps. Isolate mutations do not change the caller's process. Do not capture Flutter UI objects or nontransferable native resources. Use distinct result keys and distinct step instances for independent isolated work.

## Callbacks and result

| API | Purpose |
|---|---|
| `onStart` | Provides a `Completer<DIResult<Process, T>>` |
| `onSuccessStep` | Receives an ordinary step and its `Duration` values |
| `onSuccess` | Receives the completed container result and duration |
| `onError` | Receives error, stack trace, process, failed step, and duration |
| `result.isolatedResults` | Returned values keyed by `isolatedKey` |
| `result.repeatSteps` | Steps marked `DIStepType.repeatable` |

The constructor also accepts `onStartStep`; the imported implementation currently does not invoke it. Callbacks run in the calling isolate. Callback code should not throw.

In Flutter, create the initializer during startup and pass `result.container` to the root widget or your dependency provider. Initialize Flutter bindings before any work that uses Flutter plugins. A complete native Flutter example is in [example/](example/README.md).

## Repeat configuration

The result exposes `repeatSteps` and `runRepeat`, with overrides for the process factory, step list, and callbacks. The current `runRepeat` callback constructs an initializer but returns its `run` method reference without invoking it, so it does not perform reinitialization.

To repeat work with the imported implementation, explicitly create another initializer:

```dart
final next = DependencyInitializer<AppProcess, AppDependencies>(
  createProcess: () => AppProcess(),
  steps: result.repeatSteps,
  onStart: (completer) {
    // Observe completer.future and handle both success and errors.
  },
  onSuccess: (newResult, duration) {
    // Replace the application container.
  },
);
await next.run();
```

The factory must supply dependencies required by the selected steps. Do not provide an empty step list.

## Current execution limitations

The package was imported with its existing runtime behavior:

- The flat list is partitioned into ordinary and isolated steps. Ordinary async work is launched without awaiting it before isolated work, so there is no barrier between those groups.
- `run()` may complete before ordinary work and container creation. Observe the `onStart` completer and handle its error future even when an `onError` callback is supplied.
- The overall stopwatch is not started, so total duration values remain zero. Per-step timing is recorded for ordinary steps only.
- `onStartStep` is not invoked, and isolated steps do not invoke `onSuccessStep`.
- `runRepeat` does not execute a new run. Create a new initializer explicitly.
- There is no public cancellation API or guarantee that already spawned isolates are stopped on an error.

Use these constraints when composing dependent or long-running startup work.

## Checks

From this directory, resolve the library without resolving the Flutter example:

```sh
dart pub get --no-example
dart analyze lib
dart analyze test
dart test test/test.dart
```

The test file is named `test.dart`, so it must be passed explicitly. Two inherited error-case tests fail because their completer errors are not observed; the isolated error case also expects a step title that is not assigned. The suite does not currently provide a passing baseline for the package. The library passes static analysis.
