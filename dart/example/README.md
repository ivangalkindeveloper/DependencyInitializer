# Flutter dependency initialization example

This app builds its dependency container, loads a cat fact in an isolated step, and displays either the value or an error screen. The `dependency_initializer` path dependency points to the parent Dart package.

Requires a Flutter SDK containing Dart 3.7.2+ and a supported native device or simulator. The example calls `https://catfact.ninja/fact`, so it needs network access at runtime.

Run from this directory:

```sh
flutter pub get
flutter analyze
flutter run
```

The startup code is in `lib/main.dart`; container conversion is in `lib/core/initialization_process.dart`. Ordinary setup creates the environment and repository. The isolated step returns the fetched fact, which is read from `isolatedResults` when the container is built.

The app uses the parent package's existing scheduling, completion, and repeat behavior. Read the [package usage guide](../README.md) before adapting it to production initialization.
