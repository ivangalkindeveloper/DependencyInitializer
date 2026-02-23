import Foundation

@MainActor
final class Context<Process: DIProcess>: Sendable {
    // MARK: - Public properties
    
    let process: Process
    let startTime: DispatchTime
    //
    let repeatPreSyncSteps: [SyncInitializationStep<Process>]
    let repeatAsyncSteps: [AsyncInitializationStep<Process>]
    let repeatPostSyncSteps: [SyncInitializationStep<Process>]
    //
    var error: Error?
    
    // MARK: - Initialization
    
    init(
        process: Process,
        //
        repeatPreSyncSteps: [SyncInitializationStep<Process>],
        repeatAsyncSteps: [AsyncInitializationStep<Process>],
        repeatPostSyncSteps: [SyncInitializationStep<Process>],
    ) {
        self.process = process
        self.startTime = .now()
        //
        self.repeatPreSyncSteps = repeatPreSyncSteps
        self.repeatAsyncSteps = repeatAsyncSteps
        self.repeatPostSyncSteps = repeatPostSyncSteps
    }
    
    // MARK: - Public methods
    
    func catchError(
        _ error: Error
    ) -> Void {
        guard self.error == nil else {
            return
        }
        
        self.error = error
    }
}
