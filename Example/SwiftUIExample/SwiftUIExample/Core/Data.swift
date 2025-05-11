//
//  Dependency.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 07.05.2025.
//

import Foundation

protocol Environment {}
final class BaseEnvironment: Environment {}

protocol HttpService: AnyObject {
    var environment: Environment { get }
    func getCatFact() async throws -> CatFact
}
final class EntityService: HttpService {
    init (environment: Environment) {
        self.environment = environment
    }
    let environment: Environment
    
    func getCatFact() async throws -> CatFact {
        let (data, _) = try await URLSession.shared.data(
            for: URLRequest(
                url: URL(
                    string: "https://catfact.ninja/fact"
                )!
            )
        )

        return try JSONDecoder().decode(CatFact.self, from: data)
    }
}

protocol Database: AnyObject {
    var environment: Environment { get }
}
final class EntityDatabase: Database {
    init (environment: Environment) {
        self.environment = environment
    }
    let environment: Environment
}

protocol Repository: AnyObject {
    var service: HttpService { get }
    var database: Database { get }
    
    func getCatFact() async throws -> CatFact
}
final class EntityRepository: Repository {
    init(service: HttpService, database: Database) {
        self.service = service
        self.database = database
    }
    let service: HttpService
    let database: Database
    
    func getCatFact() async throws -> CatFact {
        try await self.service.getCatFact()
    }
}
