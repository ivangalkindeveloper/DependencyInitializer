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

        let initializer = DependencyInitializer<InitializationProcess, Dependency>(
            createProcess: { InitializationProcess() },
            steps: SceneDelegate.initializeSteps,
            onSuccess: { result, _ in
                self.setViewController(
                    MainViewController(
                        initialCatFact: result.result.initialCatFact
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
        )
        initializer.run()
    }
}

private extension SceneDelegate {
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

    private func setViewController(
        _ viewController: UIViewController
    ) {
        self.window?.rootViewController = UINavigationController(
            rootViewController: viewController
        )
        self.window?.makeKeyAndVisible()
    }
}
