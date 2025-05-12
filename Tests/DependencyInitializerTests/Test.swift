import XCTest
import SwiftUI
@testable import DependencyInitializer

@MainActor
final class DependencyInitializerTests: XCTestCase {
     func mainTest() {
        let process = TestInitializationProcess()
        DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { process },
            steps: [
                DependencyInitializerTests.dataStep,
            ],
            onSuccess: { result, _ in
                XCTAssertNotNil(process.environment)
                XCTAssertNotNil(process.service)
                XCTAssertNotNil(process.database)
                XCTAssertNotNil(process.repository)
                XCTAssertNotNil(process.environment)
                XCTAssertNotNil(process.environment)
                XCTAssertNotNil(process.environment)
                
                let dependency: TestDependency = result.container
                XCTAssertNotNil(dependency.environment)
                XCTAssertNotNil(dependency.repository)
            },
        ).run()
    }
    
    func asyncTest() {
        let process = TestInitializationProcess()
       DependencyInitializer<TestInitializationProcess, TestDependency>(
           createProcess: { process },
           steps: [
               DependencyInitializerTests.dataStep,
           ] + getAsyncStep(),
           onSuccess: { result, _ in
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.service)
               XCTAssertNotNil(process.database)
               XCTAssertNotNil(process.repository)
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.environment)
               
               let dependency: TestDependency = result.container
               XCTAssertNotNil(dependency.environment)
               XCTAssertNotNil(dependency.repository)
               XCTAssertNotNil(dependency.initialCatFact0)
               XCTAssertNotNil(dependency.initialCatFact1)
               XCTAssertNotNil(dependency.initialCatFact2)
           },
       ).run()
   }
    
    func reinitializationTest() {
       var process = TestInitializationProcess()
       DependencyInitializer<TestInitializationProcess, TestDependency>(
           createProcess: { process },
           steps: [
               DependencyInitializerTests.dataStep,
           ] + getAsyncStep(
            type: .repeatable
           ),
           onSuccess: { result, _ in
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.service)
               XCTAssertNotNil(process.database)
               XCTAssertNotNil(process.repository)
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.environment)
               XCTAssertNotNil(process.environment)
               
               let dependency: TestDependency = result.container
               XCTAssertNotNil(dependency.environment)
               XCTAssertNotNil(dependency.repository)
               XCTAssertNotNil(dependency.initialCatFact0)
               XCTAssertNotNil(dependency.initialCatFact1)
               XCTAssertNotNil(dependency.initialCatFact2)
               
               process = TestInitializationProcess()
               result.runRepeat(
                    { process },
                    nil,
                    nil,
                    nil,
                    nil,
                    { result, _ in
                        XCTAssertNotNil(process.environment)
                        XCTAssertNotNil(process.service)
                        XCTAssertNotNil(process.database)
                        XCTAssertNotNil(process.repository)
                        XCTAssertNotNil(process.environment)
                        XCTAssertNotNil(process.environment)
                        XCTAssertNotNil(process.environment)
                        
                        let dependency: TestDependency = result.container
                        XCTAssertNotNil(dependency.environment)
                        XCTAssertNotNil(dependency.repository)
                        XCTAssertNotNil(dependency.initialCatFact0)
                        XCTAssertNotNil(dependency.initialCatFact1)
                        XCTAssertNotNil(dependency.initialCatFact2)
                    },
                    nil
               )
           },
       ).run()
   }
}

private extension DependencyInitializerTests {
    static let dataStep = InitializationStep<TestInitializationProcess>(
        title: "Data",
        run: { process in
            process.environment = TestBaseEnvironment()
            process.service = TestEntityService(
                environment: process.environment!
            )
            process.database = TestEntityDatabase(
                environment: process.environment!
            )
            process.repository = TestEntityRepository(
                service: process.service!,
                database: process.database!
            )
        }
    )
        
    func getAsyncStep(
        type: DIStepType = .simple
    ) -> [AsyncInitializationStep<TestInitializationProcess>] {
        [
            AsyncInitializationStep<TestInitializationProcess>(
                title: "Cat Fact 0",
                type: type,
                run: { process in
                    sleep(1)
                    await MainActor.run {
                        process.initialCatFact0 = TestCatFact(
                            fact: "Cat fact 0",
                            length: 0
                        )
                    }
                }
            ),
            AsyncInitializationStep<TestInitializationProcess>(
                title: "Cat Fact 1",
                type: type,
                run: { process in
                    sleep(3)
                    await MainActor.run {
                        process.initialCatFact1 = TestCatFact(
                            fact: "Cat fact 1",
                            length: 0
                        )
                    }
                }
            ),
            AsyncInitializationStep<TestInitializationProcess>(
                title: "Cat Fact 2",
                type: type,
                run: { process in
                    sleep(2)
                    await MainActor.run {
                        process.initialCatFact2 = TestCatFact(
                            fact: "Cat fact 2",
                            length: 0
                        )
                    }
                }
            )
        ]
    }
}

