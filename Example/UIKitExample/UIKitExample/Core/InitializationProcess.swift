//
//  InitializationProcess.swift
//  UIKitExample
//
//  Created by Иван Галкин on 07.05.2025.
//

import DependencyInitializer

final class InitializationProcess: DependencyInitializationProcess {
    typealias T = Dependency
    
    var service: HttpService?
    var database: Database?
    var repository: Repository?
    var initialCatFact: CatFact?
    
    var toResult: Dependency {
        get {
            Dependency(
                service: self.service!,
                database: self.database!,
                repository: self.repository!,
                initialCatFact: self.initialCatFact!
            )
        }
    }
}
