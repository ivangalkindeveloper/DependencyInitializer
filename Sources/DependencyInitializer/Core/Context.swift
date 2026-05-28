import Foundation

@MainActor
final class Context<Process: DIProcess>: Sendable {
    // MARK: - Public properties
    
    let process: Process
    let startTime: DispatchTime
    let repeatStepSets: [StepSet<Process>]
    var error: Error?
    
    // MARK: - Initialization
    
    init(
        process: Process,
        repeatStepSets: [StepSet<Process>],
    ) {
        self.process = process
        self.startTime = .now()
        self.repeatStepSets = repeatStepSets
    }
    
    // MARK: - Public methods
    
    func catchError(
        _ error: Error
    ) -> Void {
        guard self.error == nil else { return }
        
        self.error = error
    }
}
