//
//  SwiftUIExampleApp.swift
//  SwiftUIExample
//
//  Created by Иван Галкин on 06.05.2025.
//

import DependencyInitializer
import SwiftUI

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
        let initializer = DependencyInitializer<InitializationProcess, Dependency>(
            createProcess: { InitializationProcess() },
            steps: AppState.initializeSteps,
            onSuccess: { [weak self] result, _ in
                self?.root = NavigationStack {
                    MainView(
                        initialCatFact: result.result.initialCatFact
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
        )
        initializer.run()
    }
}

private extension AppState {
    private static let initializeSteps: [DependencyInitializationStep] = [
        SyncInitializationStep<InitializationProcess>(
            title: "Data",
            run: { process in
                process.service = EntityService()
                process.database = EntityDatabase()
                process.repository = EntityRepository()
            }
        ),
        AsyncInitializationStep<InitializationProcess>(
            title: "Cat Fact",
            run: { process in
                let catFact = try await process.service!.getCatFact()
                await MainActor.run {
                    process.initialCatFact = catFact
                }
            }
        ),
    ]
}
