final class TestDependency: Sendable {
    init(
        environment: TestEnvironment,
        repository: TestRepository,
        initialCatFact0: TestCatFact?,
        initialCatFact1: TestCatFact?,
        initialCatFact2: TestCatFact?,
    ) {
        self.environment = environment
        self.repository = repository
        self.initialCatFact0 = initialCatFact0
        self.initialCatFact1 = initialCatFact1
        self.initialCatFact2 = initialCatFact2
    }
    
    let environment: TestEnvironment
    let repository: TestRepository
    let initialCatFact0: TestCatFact?
    let initialCatFact1: TestCatFact?
    let initialCatFact2: TestCatFact?
}
