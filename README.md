# Dependency initializer
DependencyInitializer is a convenient and understandable contract for initializing dependencies.\
The main goal is to provide a clear assembly of a dependency container with initialization steps.\
Advantages:
1) Convenient configuration - creating your own initialization steps and filling the initialization process;
2) Parallel computation of isolated steps in separate isolates;
3) Error handling;
4) Re-initialization for steps that were created as repeated, for example, for changing the environment.

# Use cases
Swift - run the initializer, get a dependency container and use it during the lifetime of the program.
UIKit - run the initializer, get a dependency container, place it in the actor for futher use.
SwiftUI - run the initializer, get a dependency container, place as EnvironmentObject for futher use.

Important points for full use:
1) Initialization steps imply not only filling the initialization process, but also the possibility of your custom checks related to business logic requests.
2) Do not forget that in case of an initialization error, you can show the error screen, and by passing the result to this widget, you can restart the initialization process using runRepeat.
Identically as for a successful launch, a similar scenario works for a test application, in particular for changing the environment without restarting the application.

# Installation
## CocoaPods
For projects with [CocoaPods](https://cocoapods.org):
```ruby
pod 'DependencyInitializer'
```
## Carthage
For projects with [Carthage](https://github.com/Carthage/Carthage):
```
github "ivangalkindeveloper/DependencyInitializer"
```
## Swift Package Manager
For projects with [Swift Package Manager](https://github.com/apple/swift-package-manager):
```
dependencies: [
    .package(url: "https://github.com/ivangalkindeveloper/DependencyInitializer.git", from: "master")
]
```

# Usage
## Container
Create a container that will be the final result of all initialization:
```swift
final class Dependency {
    init(
        environment: Environment,
        repository: Repository,
        initialCatFact: CatFact
    ) {
        self.environment = environment
        self.repository = repository
        self.initialCatFact = initialCatFact
    }
    
    let environment: Environment
    let repository: Repository
    let initialCatFact: CatFact
}
```
The container can contain not only dependency entities, but also the original domain models for business logic.
## Process
Create a process that will gradually fill up.
```swift
final class InitializationProcess: DependencyInitializationProcess {
    typealias T = Dependency
    
    var environment: Environment?
    var service: HttpService?
    var database: Database?
    var repository: Repository?
    var initialCatFact: CatFact?
    
    var toContainer: Dependency {
        get {
            Dependency(
                environment: self.environment!,
                repository: self.repository!,
                initialCatFact: self.initialCatFact!
            )
        }
    }
}
```
## Steps
The initializer runs steps in three phases in order: **preSyncSteps** (sync) → **asyncSteps** (async) → **postSyncSteps** (sync). At least one of the three lists must be non-empty.

- **preSyncSteps** — synchronous steps that run first on the main thread.
- **asyncSteps** — asynchronous steps that run in parallel (separate tasks).
- **postSyncSteps** — synchronous steps that run after async steps complete.

[DependencyInitializationStepType](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStepType.swift) - step execution type:\
simple - the step is executed once (e.g. for initializing Firebase, database and other integration packages).\
repeatable - the step is executed and remembered for re-initialization when calling runRepeat.

[SyncInitializationStep](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStep.swift) - synchronous step (for preSyncSteps and postSyncSteps).\
[AsyncInitializationStep](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStep.swift) - asynchronous step (for asyncSteps).

Prepare lists of steps:
```swift
let preSyncSteps: [SyncInitializationStep<InitializationProcess>] = [
    SyncInitializationStep<InitializationProcess>(
        run: { process in
            process.environment = BaseEnvironment()
            process.service = EntityService(
                environment: process.environment!
            )
            process.database = EntityDatabase(
                environment: process.environment!
            )
            process.repository = EntityRepository(
                service: process.service!,
                database: process.database!
            )
        }
    ),
]

let asyncSteps: [AsyncInitializationStep<InitializationProcess>] = [
    AsyncInitializationStep<InitializationProcess>(
        run: { process in
            let catFact = try await process.repository!.getCatFact()
            await MainActor.run {
                process.initialCatFact = catFact
            }
        }
    ),
]

let postSyncSteps: [SyncInitializationStep<InitializationProcess>] = [
    // optional sync steps after async
]
```
## DependencyInitializer
Create initializer and start initialize process. Pass **preSyncSteps**, **asyncSteps**, and **postSyncSteps** (each optional; at least one must be non-empty).\
Example for UIKit:
```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let scene = (scene as? UIWindowScene) else { return }
    self.window = UIWindow(windowScene: scene)

    DependencyInitializer<InitializationProcess, Dependency>(
        createProcess: { InitializationProcess() },
        preSyncSteps: preSyncSteps,
        asyncSteps: asyncSteps,
        postSyncSteps: postSyncSteps,
        onSuccess: { result, _ in
            self.setViewController(
                MainViewController(
                    initialCatFact: result.container.initialCatFact
                )
            )
        },
        onError: { error, _, _, _ in
            self.setViewController(
                ErrorViewController(
                    error: error
                )
            )
        }
    ).run()
}
```
Example for SwiftUI:
```swift
@main
struct SwiftUIExampleApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            AnyView(self.state.root)
                .onAppear {
                    self.state.initialize()
                }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var root: any View = EmptyView()

    func initialize() {
        DependencyInitializer<InitializationProcess, Dependency>(
            createProcess: { InitializationProcess() },
            preSyncSteps: AppState.preSyncSteps,
            asyncSteps: AppState.asyncSteps,
            postSyncSteps: AppState.postSyncSteps,
            onSuccess: { [weak self] result, _ in
                self?.root = NavigationStack {
                    MainView(
                        initialCatFact: result.container.initialCatFact
                    )
                }
            },
            onError: { [weak self] error, _, _, _ in
                self?.root = NavigationStack {
                    ErrorView(
                        error: error
                    )
                }
            }
        ).run()
    }
}
```

# Usage examples
Initializer has several use cases:
1) Direct.\
For example, if you want the Flutter application to show a native splash screen when it starts, and then launch the first widget.
```swift
DependencyInitializer<InitializationProcess, Dependency>(
    createProcess: { InitializationProcess() },
    preSyncSteps: preSyncSteps,
    asyncSteps: asyncSteps,
    postSyncSteps: postSyncSteps,
    onSuccess: { [weak self] _, _ in
        // Success case
    },
    onError: { [weak self] _, _, _, _ in
        // Error case
    }
).run()
```

2) Reinitialization from result.\
For example, in the runtime of a Flutter application, you need to reinitialize your new dependencies for the new environment and return the first widget of the Flutter application again.
```swift
result.runRepeat(
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    { result, _ in
        // Success case
    },
    { _, _, _, _ in
        // Error case
    }
)
```

# Additional information
For more details see example project.\
And feel free to open an issue if you find any bugs or errors or suggestions.
