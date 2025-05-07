//
//  Dependency.swift
//  UIKitExample
//
//  Created by Иван Галкин on 07.05.2025.
//

final class Dependency {
    init(
        service: HttpService,
        database: Database,
        repository: Repository,
        initialCatFact: CatFact
    ) {
        self.service = service
        self.database = database
        self.repository = repository
        self.initialCatFact = initialCatFact
    }
    
    let service: HttpService
    let database: Database
    let repository: Repository
    let initialCatFact: CatFact
}
