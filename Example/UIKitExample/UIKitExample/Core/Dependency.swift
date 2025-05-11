//
//  Dependency.swift
//  UIKitExample
//
//  Created by Иван Галкин on 07.05.2025.
//

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
