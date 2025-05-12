//
//  TestInitializationProcess.swift
//  DependencyInitializer
//
//  Created by Иван Галкин on 13.05.2025.
//

@testable import DependencyInitializer

final class TestInitializationProcess: DependencyInitializationProcess {
    typealias T = TestDependency
    
    var environment: TestEnvironment?
    var service: TestHttpService?
    var database: TestDatabase?
    var repository: TestRepository?
    var initialCatFact0: TestCatFact?
    var initialCatFact1: TestCatFact?
    var initialCatFact2: TestCatFact?
    
    var toContainer: TestDependency {
        get {
            TestDependency(
                environment: self.environment!,
                repository: self.repository!,
                initialCatFact0: self.initialCatFact0,
                initialCatFact1: self.initialCatFact1,
                initialCatFact2: self.initialCatFact2
            )
        }
    }
}
