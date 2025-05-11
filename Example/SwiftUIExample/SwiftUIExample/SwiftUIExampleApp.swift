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

private extension AppState {
    private static let initializationSteps: [DependencyInitializationStep] = [
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
}
