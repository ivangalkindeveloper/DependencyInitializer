public final class DependencyInitializationResult<Process: DependencyInitializationProcess, T> {
    // MARK: - Public properties
    
    public let container: T
    public let repeatStepSets: [StepSet<Process>]
    public let runRepeat: DIRepeatCallback<Process, T>
    
    // MARK: - Initialization
    
    init(
        container: T,
        repeatStepSets: [StepSet<Process>],
        runRepeat: @escaping DIRepeatCallback<Process, T>
    ) {
        self.container = container
        self.repeatStepSets = repeatStepSets
        self.runRepeat = runRepeat
    }
}
