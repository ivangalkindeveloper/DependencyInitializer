@testable import DependencyInitializer
import Testing
import SwiftUI

@MainActor
@Suite("DependencyInitializer")
struct DependencyInitializerTests {

    @Test func preSyncSteps() async {
        let process = TestInitializationProcess()
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { process },
            preSyncSteps: Self.preSyncSteps,
            onSuccess: { result, _ in
                #expect(process.environment != nil)
                #expect(process.service != nil)
                #expect(process.database != nil)
                #expect(process.repository != nil)
                #expect(process.initialCatFact0 != nil)
                #expect(process.initialCatFact1 == nil)
                #expect(process.initialCatFact2 == nil)
                
                let dependency: TestDependency = result.container
                #expect(dependency.initialCatFact0 != nil)
                #expect(dependency.initialCatFact1 == nil)
                #expect(dependency.initialCatFact2 == nil)
            },
        ).run()
    }

    @Test func asyncSteps() async {
        let process = TestInitializationProcess()
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { process },
            preSyncSteps: Self.preSyncSteps,
            asyncSteps: asyncSteps(.simple),
            onSuccess: { result, _ in
                #expect(process.environment != nil)
                #expect(process.service != nil)
                #expect(process.database != nil)
                #expect(process.repository != nil)
                #expect(process.initialCatFact0 != nil)
                #expect(process.initialCatFact1 != nil)
                #expect(process.initialCatFact2 == nil)
                
                let dependency: TestDependency = result.container
                #expect(dependency.initialCatFact0 != nil)
                #expect(dependency.initialCatFact1 != nil)
                #expect(dependency.initialCatFact2 == nil)
            },
        ).run()
    }
    
    @Test func postSyncSteps() async {
        let process = TestInitializationProcess()
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { process },
            preSyncSteps: Self.preSyncSteps,
            asyncSteps: asyncSteps(.simple),
            postSyncSteps: Self.postSyncSteps,
            onSuccess: { result, _ in
                #expect(process.environment != nil)
                #expect(process.service != nil)
                #expect(process.database != nil)
                #expect(process.repository != nil)
                #expect(process.initialCatFact0 != nil)
                #expect(process.initialCatFact1 != nil)
                #expect(process.initialCatFact2 != nil)
                
                let dependency: TestDependency = result.container
                #expect(dependency.initialCatFact0 != nil)
                #expect(dependency.initialCatFact1 != nil)
                #expect(dependency.initialCatFact2 != nil)
            },
        ).run()
    }

    @Test func reinitialization() async {
        let process = TestInitializationProcess()
        var initResult: DependencyInitializationResult<TestInitializationProcess, TestDependency>?
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { process },
            preSyncSteps: Self.preSyncSteps,
            asyncSteps: asyncSteps(.repeatable),
            postSyncSteps: Self.postSyncSteps,
            onSuccess: { result, _ in
                #expect(process.environment != nil)
                #expect(process.service != nil)
                #expect(process.database != nil)
                #expect(process.repository != nil)
                
                let dependency: TestDependency = result.container
                #expect(dependency.initialCatFact0 != nil)
                #expect(dependency.initialCatFact1 != nil)
                #expect(dependency.initialCatFact2 != nil)
                initResult = result
            },
        ).run()

        guard let result = initResult else { return }
        let repeatProcess = TestInitializationProcess()
        await result.runRepeat(
            { repeatProcess },
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            { result, _ in
                MainActor.assumeIsolated {
                    #expect(repeatProcess.environment != nil)
                    #expect(repeatProcess.service != nil)
                    #expect(repeatProcess.database != nil)
                    #expect(repeatProcess.repository != nil)
                }
                let dependency: TestDependency = result.container
                #expect(dependency.initialCatFact0 != nil)
                #expect(dependency.initialCatFact1 != nil)
                #expect(dependency.initialCatFact2 != nil)
            },
            nil
        )
    }

    @Test func errorPreSyncStep() async {
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { TestInitializationProcess() },
            preSyncSteps: [
                SyncInitializationStep<TestInitializationProcess>(
                    run: { _ in
                        throw NSError(
                            domain: "TestError",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Test error"])
                    }
                )
            ],
            onError: { error, _, _, _ in
                #expect((error as NSError).domain == "TestError")
                #expect((error as NSError).code == 0)
                #expect((error as NSError).localizedDescription == "Test error")
            }
        ).run()
    }

    @Test func errorAsyncStep() async {
        await DependencyInitializer<TestInitializationProcess, TestDependency>(
            createProcess: { TestInitializationProcess() },
            asyncSteps: [
                AsyncInitializationStep<TestInitializationProcess>(
                    run: { _ in
                        throw NSError(
                            domain: "TestError",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Test error"])
                    }
                )
            ],
            onError: { error, _, _, _ in
                #expect((error as NSError).domain == "TestError")
                #expect((error as NSError).code == 0)
                #expect((error as NSError).localizedDescription == "Test error")
            }
        ).run()
    }
}

private extension DependencyInitializerTests {
    static let preSyncSteps: [SyncInitializationStep<TestInitializationProcess>] = [
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.environment = TestBaseEnvironment()
            }
        ),
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.service = TestEntityService(
                    environment: process.environment!
                )
            }
        ),
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.database = TestEntityDatabase(
                    environment: process.environment!
                )
            }
        ),
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.repository = TestEntityRepository(
                    service: process.service!,
                    database: process.database!
                )
            }
        ),
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.initialCatFact0 = TestCatFact(
                    fact: "Cat fact 0"
                )
            }
        )
    ]

    func asyncSteps(_ type: DIStepType) -> [AsyncInitializationStep<TestInitializationProcess>] {
        [
            AsyncInitializationStep<TestInitializationProcess>(
                type: type,
                run: { process in
                    sleep(1)
                    await MainActor.run {
                        process.initialCatFact1 = TestCatFact(
                            fact: "Cat fact 1"
                        )
                    }
                }
            ),
        ]
    }
    
    static let postSyncSteps: [SyncInitializationStep<TestInitializationProcess>] = [
        SyncInitializationStep<TestInitializationProcess>(
            run: { process in
                process.initialCatFact2 = TestCatFact(
                    fact: "Cat fact 2"
                )
            }
        )
    ]
}
