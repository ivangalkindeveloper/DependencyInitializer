# Changelog

## 4.0.0

This major release combines Swift, Kotlin / Android, and Dart / Flutter implementations in the existing DependencyInitializer repository. Release version `4.0.0` is shared across the implementations; their APIs and execution semantics remain platform-specific.

### Changes

- Move the Swift package, tests, and examples into `swift/`.
- Add the Kotlin coroutine implementation and Android Compose sample in `kotlin/`, using the `io.ivangalkindeveloper.dependencyinitializer` namespace.
- Add the Dart package and Flutter example in `dart/`, without importing their separate Git repository or history.
- Retain the root `Package.swift` so the existing Swift Package Manager repository URL continues to resolve.
- Align the Swift release tag, Kotlin library version, Dart package version, and example versions at `4.0.0`.
- Provide English usage guides for each implementation and a root README focused on platform differences.
- Add GitHub Actions checks for Swift and Kotlin / Android.

### Migration

- Swift: keep the existing repository URL and use `.package(url: "https://github.com/ivangalkindeveloper/DependencyInitializer.git", from: "4.0.0")`. Direct source and local package paths now use `swift/`.
- Kotlin: open or include `kotlin/`, import `io.ivangalkindeveloper.dependencyinitializer`, and use `io.ivangalkindeveloper:dependency-initializer:4.0.0` after publishing to Maven Local.
- Dart / Flutter: use the DependencyInitializer Git repository with `ref: v4.0.0` and `path: dart`. The Dart package name remains `dependency_initializer`.
- Swift and Kotlin use ordered step sets. Dart uses a flat step list with ordinary and isolated steps; see the [platform comparison](README.md) before adapting initialization flows.
- Consult [Swift usage](swift/README.md), [Kotlin usage](kotlin/README.md), or [Dart usage](dart/README.md) for installation and examples.

### Validation and known limitations

- Swift package build and all 7 tests passed.
- Kotlin tests, Android debug build, lint, and Maven Local publication passed.
- Dart library and test static analysis passed.
- Dart tests: 3 passed and 2 inherited error-case tests failed. Their completer errors are not observed; the isolated error case also expects a step title that is not assigned.
- The imported Dart runtime retains its existing limitations: ordinary async work is not awaited before isolated work, `run()` can complete early, total duration remains zero, some step callbacks are not invoked, and `runRepeat` does not invoke a new run. See the [Dart usage guide](dart/README.md) for completion handling and the explicit reinitialization workaround.
- The legacy Swift example projects still reference an older step API. The current Swift package tests and usage guide use the supported step-set API.

This is a GitHub source release. Maven Central and pub.dev publication are separate distribution steps. This repository consolidation does not fix the inherited Dart runtime issues or legacy Swift examples.
