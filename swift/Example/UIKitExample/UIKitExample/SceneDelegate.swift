//
//  SceneDelegate.swift
//  UIKitExample
//
//  Created by Иван Галкин on 06.05.2025.
//

import DependencyInitializer
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else { return }
        self.window = UIWindow(windowScene: scene)

        DependencyInitializer<InitializationProcess, Dependency>(
            createProcess: { InitializationProcess() },
            steps: SceneDelegate.initializationSteps,
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
}

private extension SceneDelegate {
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

    private func setViewController(
        _ viewController: UIViewController
    ) {
        self.window?.rootViewController = UINavigationController(
            rootViewController: viewController
        )
        self.window?.makeKeyAndVisible()
    }
}
