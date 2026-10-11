# DependencyInitializer

DependencyInitializer собирает контейнер зависимостей через последовательность наборов шагов. Синхронные шаги выполняются по одному, асинхронные шаги одного набора — параллельно; следующий набор начинается после завершения предыдущего. Есть callbacks прогресса, обработка ошибок, измерение времени и повторная инициализация.

В одном репозитории находятся самостоятельные реализации для Apple-платформ и Android:

| | Swift | Kotlin |
|---|---|---|
| Исходники и документация | [swift/](swift/) · [Swift README](swift/README.md) | [kotlin/](kotlin/) · [Kotlin README](kotlin/README.md) |
| Платформы | iOS 13+, macOS 10.15+ | JVM-библиотека; Android-пример API 23+ |
| Инструменты сборки | Swift 6.0+, Swift Package Manager / Xcode | JDK 17, Gradle Wrapper; Android SDK 36 для примера |
| Модуль / namespace | `DependencyInitializer` | `io.ivangalkindeveloper.dependencyinitializer` |
| Контракт процесса | `DependencyInitializationProcess` с associatedtype | `DependencyInitializationProcess<T>`, alias `DIProcess<T>` |
| Sync-шаги и callbacks | `MainActor` | `mainDispatcher`, по умолчанию `Dispatchers.Main.immediate` |
| Async-шаги | Swift Task Group, `TaskPriority` | Дочерние корутины, `asyncDispatcher` и dispatcher шага |
| Результат запуска | `run() async`, результат через callback | `suspend run(): DIResult<P, T>?` и callbacks |
| Примеры | UIKit, SwiftUI в `swift/Example/` | Compose-приложение в `kotlin/sample/` |

Обе версии сохраняют `StepSet`, `SyncInitializationStep`, `AsyncInitializationStep`, типы simple / repeatable и повторный запуск. При ошибке шага следующие наборы не выполняются; уже запущенные async-шаги завершаются. Время передаётся как `Double` в наносекундах.

`runRepeat()` без overrides запускает **все исходные наборы**, включая simple. Чтобы повторить только repeatable-шаги, передайте `result.repeatStepSets` и фабрику процесса с уже созданными зависимостями, которые нужны этим шагам. Это соответствует фактическому поведению Swift-реализации.

В Kotlin запуск привязан к scope вызывающей корутины; отмена передаётся как `CancellationException` и отменяет дочерние задачи. Kotlin не проверяет `Sendable` и изоляцию `MainActor` на уровне компилятора: доступ к общим полям процесса нужно переносить на main dispatcher или синхронизировать. Dispatcher задаёт контекст выполнения, а не приоритет Swift Task.

## Swift

Подключение через Swift Package Manager:

```swift
.package(
    url: "https://github.com/ivangalkindeveloper/DependencyInitializer.git",
    branch: "master"
)
```

Корневой `Package.swift` указывает на `swift/Sources` и `swift/Tests`, сохраняя подключение по прежнему URL. В `swift/` также есть самостоятельный Swift-пакет.

```sh
swift test
# Либо непосредственно Swift-реализацию:
swift test --package-path swift
```

Примеры Xcode находятся в [swift/Example/](swift/Example/); их локальная зависимость указывает на Swift-пакет в `swift/`. Сборка контейнера, callbacks и retry описаны в [swift/README.md](swift/README.md).

Исходные SwiftUI- и UIKit-примеры сохранены, но пока используют удалённый `InitializationStep` и не собираются с текущим API. Их нужно обновить на `StepSet`, `SyncInitializationStep` и `AsyncInitializationStep`. Это ограничение примеров; сама Swift-библиотека и её тесты собираются.

## Kotlin / Android

Откройте `kotlin/` в Android Studio. Модуль `dependency-initializer` содержит JVM-библиотеку, `sample` — Android-пример с прогрессом, ошибкой, retry и сменой окружения.

```sh
cd kotlin
./gradlew test assembleDebug lintDebug publishToMavenLocal
```

Android SDK задаётся через `ANDROID_HOME` или `kotlin/local.properties`. После локальной публикации добавьте `mavenLocal()` в repositories приложения:

```kotlin
implementation("io.ivangalkindeveloper:dependency-initializer:1.0.0")
```

Альтернатива — `includeBuild("/absolute/path/to/DependencyInitializer/kotlin")` в `settings.gradle.kts` приложения. Библиотека не зависит от Handler, Router или Compose. API, обработка ошибок и правила повторного запуска — в [kotlin/README.md](kotlin/README.md). Публикация в удалённый Maven-репозиторий настраивается отдельно.

## Структура и проверки

- `swift/` — Swift Package, исходники, тесты, UIKit- и SwiftUI-примеры, документация.
- `kotlin/` — Gradle-проект, JVM-библиотека, Android-пример, тесты и документация.
- `Package.swift` — вход для Swift Package Manager из корня репозитория.
- `.github/` — общие GitHub Actions; Kotlin-команды выполняются в `kotlin/`.

Реализации собираются независимо. История Swift, существующие теги и история Kotlin сохранены в общем Git-репозитории. Проверки покрывают порядок и параллельность шагов, ошибки, callbacks и повторные запуски; Kotlin-проверки дополнительно включают Android-сборку и Lint.
