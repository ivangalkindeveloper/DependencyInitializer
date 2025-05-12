//
//  DependencyInitializerTestData.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 13.05.2025.
//

protocol TestEnvironment: Sendable {}
final class TestBaseEnvironment: TestEnvironment {}

protocol TestHttpService: AnyObject, Sendable {
    var environment: TestEnvironment { get }
}
final class TestEntityService: TestHttpService {
    init (environment: TestEnvironment) {
        self.environment = environment
    }
    let environment: TestEnvironment
}

protocol TestDatabase: AnyObject, Sendable {
    var environment: TestEnvironment { get }
}
final class TestEntityDatabase: TestDatabase {
    init (environment: TestEnvironment) {
        self.environment = environment
    }
    let environment: TestEnvironment
}

protocol TestRepository: AnyObject, Sendable {
    var service: TestHttpService { get }
    var database: TestDatabase { get }
}
final class TestEntityRepository: TestRepository {
    init(service: TestHttpService, database: TestDatabase) {
        self.service = service
        self.database = database
    }
    let service: TestHttpService
    let database: TestDatabase
}
