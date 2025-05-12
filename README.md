
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
[DependencyInitializationStepType](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStepType.swift) - step execution type:\
simple - the step is executed once, this is useful for example for initializing Firebase, database and other integration packages.\
repeatable - the step is executed and remembered for further repeated execution when calling re-initialization using the runRepeat function.\
[InitializationStep](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStep.swift) - async execution step in the current main thread.\
[AsyncInitializationStep](https://github.com/ivangalkindeveloper/DependencyInitializer/blob/master/Sources/DependencyInitializer/DependencyInitializationStep.swift) - async execution step in the new parallel thread.
Prepare list of initialize steps:
```swift
let steps: [DependencyInitializationStep] = [
    InitializationStep<InitializationProcess>(
        title: "Data",
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
    AsyncInitializationStep<InitializationProcess>(
        title: "Cat Fact",
        run: { process in
            let catFact = try await process.repository!.getCatFact()
            await MainActor.run {
                process.initialCatFact = catFact
            }
        }
    ),
]
```
## DependencyInitializer
Create initializer and start initialize process.\
Example for UIKit:
```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    guard let scene = (scene as? UIWindowScene) else { return }
    self.window = UIWindow(windowScene: scene)

    DependencyInitializer<InitializationProcess, Dependency>(
        createProcess: { InitializationProcess() },
        steps: steps,
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
            steps: AppState.initializationSteps,
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
    steps: AppState.initializationSteps,
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
    steps: [
        InitializationStep<InitializationProcess>(
            title: "Environment",
            run: { process in
                process.environment = NewEnvironment()
            }
        ),
    ] + result.repeatSteps,
    onSuccess: { [weak self] _, _ in
        // Success case
    },
    onError: { [weak self] _, _, _, _ in
        // Error case
    }
);
```

# Additional information
For more details see example project.\
And feel free to open an issue if you find any bugs or errors or suggestions.
