public final class DependencyInitializationResult<Process: DependencyInitializationProcess, T> {
    // MARK: - Public properties
    
    public let container: T
    public let repeatPreSyncSteps: [SyncInitializationStep<Process>]
    public let repeatAsyncSteps: [AsyncInitializationStep<Process>]
    public let repeatPostSyncSteps: [SyncInitializationStep<Process>]
    public let runRepeat: DIRepeatCallback<Process, T>
    
    // MARK: - Initialization
    
    init(
        container: T,
        repeatPreSyncSteps: [SyncInitializationStep<Process>],
        repeatAsyncSteps: [AsyncInitializationStep<Process>],
        repeatPostSyncSteps: [SyncInitializationStep<Process>],
        runRepeat: @escaping DIRepeatCallback<Process, T>
    ) {
        self.container = container
        self.repeatPreSyncSteps = repeatPreSyncSteps
        self.repeatAsyncSteps = repeatAsyncSteps
        self.repeatPostSyncSteps = repeatPostSyncSteps
        self.runRepeat = runRepeat
    }
}
