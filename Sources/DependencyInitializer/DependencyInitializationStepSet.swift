public final class DependencyInitializationStepSet<Process: DIProcess> {
    // MARK: - Kind

    enum Kind {
        case sync([SyncInitializationStep<Process>])
        case async([AsyncInitializationStep<Process>])
    }

    // MARK: - Internal properties

    let kind: Kind

    // MARK: - Initialization

    public init(
        sync steps: [SyncInitializationStep<Process>]
    ) {
        self.kind = .sync(steps)
    }

    public init(
        async steps: [AsyncInitializationStep<Process>]
    ) {
        self.kind = .async(steps)
    }
}

// MARK: - Internal methods

extension DependencyInitializationStepSet {
    var repeatable: DependencyInitializationStepSet<Process>? {
        switch self.kind {
        case .sync(let steps):
            let filtered = steps.filter { $0.type == .repeatable }
            return filtered.isEmpty ? nil : DependencyInitializationStepSet(sync: filtered)
        case .async(let steps):
            let filtered = steps.filter { $0.type == .repeatable }
            return filtered.isEmpty ? nil : DependencyInitializationStepSet(async: filtered)
        }
    }
}
