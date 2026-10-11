//
//  InitializationProcess.swift
//  UIKitExample
//
//  Created by Иван Галкин on 07.05.2025.
//

import DependencyInitializer

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
