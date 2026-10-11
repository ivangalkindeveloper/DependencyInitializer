# DependencyInitializer для Kotlin / Android

Эта реализация находится в общем репозитории DependencyInitializer. [Обзор проекта и Swift-версия](../README.md). Все команды ниже выполняются из каталога `kotlin/`; открывайте его в Android Studio.

Порт Swift-пакета `DependencyInitializer`: сборка контейнера зависимостей через процесс инициализации, последовательные наборы шагов, параллельные асинхронные шаги, callbacks, обработка ошибок, измерение времени и повторный запуск.

Модули:

- `dependency-initializer` — библиотека JVM JAR с Kotlin Coroutines, пригодная для Android Views, Compose и обычного JVM-проекта.
- `sample` — запускаемое Android-приложение: прогресс инициализации, параллельная загрузка данных, ошибка и retry, полная переинициализация и смена окружения с сохранением базы данных.

## Сборка и подключение

JDK 17 и Gradle Wrapper 8.13. Библиотека использует Kotlin 2.2.21, Coroutines 1.10.2 и байткод Java 8. Для Android-примера нужны Android SDK 36 и Build Tools 35.0.0; его минимальная версия Android — API 23.

```sh
./gradlew test assembleDebug lintDebug publishToMavenLocal
```

SDK укажите через `ANDROID_HOME` или исключённый из Git `local.properties`:

```properties
sdk.dir=/absolute/path/to/Android/sdk
```

В `settings.gradle.kts` приложения добавьте `mavenLocal()` в `dependencyResolutionManagement.repositories`, сохранив `google()` и `mavenCentral()`. Затем:

```kotlin
dependencies {
    implementation("io.ivangalkindeveloper:dependency-initializer:1.0.0")
}
```

Альтернативное подключение исходников: `includeBuild("/absolute/path/to/DependencyInitializer/kotlin")` в settings; строка зависимости остаётся той же. Библиотека не зависит от Handler, Router или Compose. `kotlinx-coroutines-android` подключается транзитивно для главного dispatcher; в обычном JVM-проекте передайте свой `mainDispatcher`.

## Контейнер, процесс и шаги

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
            delay(100) // Здесь можно вызвать suspend-метод repository.
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

`stepSets` должен быть непустым. Отдельные пустые наборы допустимы и пропускаются. `StepSet` принимает либо `sync`, либо `async`; одновременная передача обоих или отсутствие обоих — ошибка конфигурации.

Наборы выполняются строго по порядку. Синхронные шаги внутри набора выполняются по одному на `mainDispatcher`. Асинхронные шаги одного набора запускаются параллельно на `asyncDispatcher` и полностью завершаются перед следующим набором. Шаги, зависящие от результатов других async-шагов, поместите в следующий набор.

## Запуск в Android

`run()` — suspend-функция. Запускайте её из `viewModelScope`, `lifecycleScope` или application scope согласно нужному времени жизни:

```kotlin
viewModelScope.launch {
    val result = DependencyInitializer(
        createProcess = { InitializationProcess() },
        stepSets = stepSets,
        onStart = { /* показать загрузку */ },
        onStartStep = { step -> /* обновить прогресс */ },
        onSuccessStep = { step, stepNanos, totalNanos -> /* логировать время */ },
        onSuccess = { result, totalNanos -> /* сохранить result.container */ },
        onError = { error, process, step, totalNanos -> /* показать ошибку */ },
    ).run()
    // result == null после ошибки шага; иначе доступен result.container.
}
```

Производство процесса, синхронные шаги, получение `toContainer` и все callbacks выполняются на `Dispatchers.Main.immediate` по умолчанию. Асинхронные шаги — на `Dispatchers.Default`; для блокирующего IO у конкретного шага задайте `dispatcher = Dispatchers.IO`. `mainDispatcher` и `asyncDispatcher` можно подменить при тестировании. Dispatcher для main должен выполнять callbacks последовательно.

Процесс разделяется между async-шагами. Kotlin не проверяет Swift `Sendable`/`MainActor` на уровне компилятора: изменения общих полей процесса переносите на main через `withContext`, как в примере, либо синхронизируйте собственную модель. Не блокируйте main длительными синхронными шагами. [Документация Dispatchers.Main](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-main.html).

## Ошибки и отмена

Ошибка синхронного шага прекращает текущий набор и все последующие. При ошибках async-шагов `onError` вызывается только для первой зарегистрированной ошибки, а уже запущенные соседние шаги завершаются; успешные соседи всё ещё вызывают `onSuccessStep`. Следующие наборы не запускаются. Итоговый контейнер и `onSuccess` не создаются после ошибки; `run()` возвращает `null`.

`onError` получает исходное исключение, тот же экземпляр процесса, конкретный шаг и общее время. Без `onError` ошибка шага также приводит к `null`. Для retry после неудачи снова вызовите `initializer.run()` — он создаёт новый процесс каждый раз.

Отмена вызывающей корутины отменяет весь запуск и дочерние async-задачи. `CancellationException` пробрасывается и не вызывает `onError`/`onSuccess`; отмена отдельного async-шага также прекращает запуск. Используется cancellable `awaitAll`, включая распространение отмены. [Документация awaitAll](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/await-all.html).

Callbacks должны завершаться без исключений. Ошибки callbacks, `createProcess`, `toContainer` и фатальные JVM `Error` пробрасываются вызывающей корутине, поскольку они не являются ошибками конкретного шага. Обычные исключения тела шага обрабатываются через `onError`. Не запускайте повторную инициализацию с тем же изменяемым процессом одновременно.

## Повторная инициализация

```kotlin
val repeated = result.runRepeat() // Все исходные наборы, новый процесс.

val sandbox = result.runRepeat(
    createProcess = { InitializationProcess(environment = "Sandbox") },
    stepSets = result.repeatStepSets, // Только шаги REPEATABLE.
    onSuccess = { newResult, _ -> /* заменить контейнер */ },
)
```

Поведение соответствует фактическому Swift-коду: **`runRepeat()` без параметров запускает все исходные наборы**, включая `SIMPLE`. `repeatStepSets` — отдельный список, который фильтрует только `REPEATABLE`, сохраняя порядок и вид наборов; пустые после фильтрации наборы не входят в список.

Чтобы повторить только эти шаги, передайте `stepSets = result.repeatStepSets` и фабрику процесса, содержащего необходимые зависимости из простых шагов. В `sample` смена окружения создаёт новый процесс с прежней базой данных, затем повторно создаёт repository и загружает данные. Пустой `repeatStepSets` нельзя передать в initializer: в таком случае повторяемых шагов нет.

Каждый ненулевой параметр `runRepeat` заменяет соответствующую фабрику, наборы или callback; `null` наследует прежнее значение. Для отключения унаследованного callback передайте пустую lambda. У повторного результата сохраняется конфигурация именно его запуска, поэтому дальнейшие повторы используют последние overrides.

## Соответствие Swift API

| Swift | Kotlin |
|---|---|
| `DependencyInitializationProcess` с associatedtype | `DependencyInitializationProcess<T>` |
| `SyncInitializationStep` / `AsyncInitializationStep` | Те же имена и поле `run` |
| `.simple` / `.repeatable` | `SIMPLE` / `REPEATABLE` |
| `StepSet(sync:)` / `StepSet(async:)` | `StepSet(sync = ...)` / `StepSet(async = ...)` |
| `TaskPriority` | `dispatcher`, выбирающий контекст выполнения |
| `MainActor` | `mainDispatcher`, по умолчанию Main.immediate |
| `run() async → Void` | `suspend run() → DIResult<P,T>?` и прежние callbacks |
| `result.runRepeat` — async closure | `result.runRepeat(...)` — suspend-метод с именованными параметрами |

Сохранены aliases `DIProcess`, `DIStep`, `DIStepType`, `StepSet`, `DIStepSet`, `DIResult`, `DIRepeatCallback`. `run` дополнительно возвращает результат, чтобы им можно было пользоваться без callback. Kotlin проверяет соответствие типа контейнера типу процесса.

Как в Swift `TimeDispatcher`, durations — **Double в наносекундах**, отсчитанные по монотонным часам. Для миллисекунд разделите на `1_000_000.0`, для секунд — на `1_000_000_000.0`. Async step duration включает выполнение шага и передачу результата на main, но не ожидание до старта worker; общее время начинается после создания процесса и включает callbacks.

## Пример, проверки и GitHub

Откройте каталог в Android Studio и запустите модуль `sample`. Данные repository имитируются локально через `delay`, поэтому пример работает без сети. APK после `./gradlew :sample:assembleDebug` находится в `sample/build/outputs/apk/debug/`.

Тесты проверяют порядок шагов и callbacks, параллельность и барьеры между наборами, ошибки и отмену, фильтрацию и полный/частичный repeat, время в наносекундах, реальные потоки callbacks, dispatcher отдельного шага и защиту списков от изменения. GitHub Actions собирает Android-пример, выполняет тесты, Lint и локальную Maven-публикацию.

Git-репозиторий общий для Swift и Kotlin. Git-команды выполняйте из корня проекта; GitHub Actions находятся в `../.github/`.

Удалённая Maven-публикация требует отдельной настройки адреса и credentials; `publishToMavenLocal` уже настроен.
