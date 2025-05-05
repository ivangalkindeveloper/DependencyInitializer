// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@available(iOS 13.0, *)
@available(macOS 10.15, *)
@MainActor
public final class DependencyInitializer<
    Process: DependencyInitializationProcess,
    Step: DependencyInitializationStep,
    T
>: NSObject where Process.T == T, Step.Process == Process {
    // MARK: - Private properties

    private let createProcess: () -> Process
    private let steps: [Step]
    private let onStart: (() -> Void)?
    private let onStartStep: ((Step) -> Void)?
    private let onSuccessStep: ((Step, Double) -> Void)?
    private let onSuccess: ((DIResult<Process, Step, T>, Double) -> Void)?
    private let onError: ((Error, Process, Step, Double) -> Void)?

    // MARK: - Initialization

    init(
        createProcess: @escaping () -> Process,
        steps: [Step],
        onStart: (() -> Void)? = nil,
        onStartStep: ((Step) -> Void)? = nil,
        onSuccessStep: ((Step, Double) -> Void)? = nil,
        onSuccess: ((DIResult<Process, Step, T>, Double) -> Void)? = nil,
        onError: ((Error, Process, Step, Double) -> Void)? = nil
    ) {
        self.createProcess = createProcess
        self.steps = steps
        self.onStart = onStart
        self.onStartStep = onStartStep
        self.onSuccessStep = onSuccessStep
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    // MARK: - Public methods
    
    func run() async {
        assert(self.steps.isEmpty == false, "Step list can't be empty")
        
        let startTime = DispatchTime.now()
        let currentProcess: Process = self.createProcess()
        let context = self.getContext()
        

        try? await withThrowingTaskGroup(of: Void.self) { group in
            for step in steps {
                guard context.encounteredError == nil else {
                    group.cancelAll()
                    break
                }
                
                // TODO: - синхронная работа с процессом
                
                group.addTask(
                    priority: step.taskPriority
                ) { [weak self, weak currentProcess, weak context] in
                    guard let self = self,
                          let currentProcess = currentProcess,
                          let context = context else { return }

                    do {
                        let stepStartTime = DispatchTime.now()
                        try await step.initialize(currentProcess)
                        await MainActor.run {
                            self.onSuccessStep?(
                                step,
                                self.endDispatchTime(stepStartTime)
                            )
                        }
                    } catch {

                        await MainActor.run {
                            if context.encounteredError == nil {
                                context.encounteredError = error
                            }
                            self.onError?(
                                error,
                                currentProcess,
                                step,
                                self.endDispatchTime(startTime)
                            )
                        }
                    }
                }
            }
            
            try await group.waitForAll()
        }

        self.onSuccess?(
            DependencyInitializationResult(
                result: currentProcess.toResult,
                reinitializationStepList: context.repeatSteps,
                runRepeat: self.runRepeat(
                    repeatSteps: context.repeatSteps
                ),
            ),
            self.endDispatchTime(startTime)
        )
    }
    
    
    // MARK: - Private methods
    
    private func executeStep() {}
    
    private func endDispatchTime(
        _ start: DispatchTime
    ) -> Double {
        let end = DispatchTime.now()
        let difference: UInt64 = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(difference)
    }
    
    private func getContext() -> Context<Step> {
        var repeatSteps: [Step] = []
        
        for step in self.steps {
            switch step.type {
            case .simple:
                break
            case .repeatable:
                repeatSteps.append(step)
                break
            }
        }
        
        return Context(
            repeatSteps: repeatSteps,

        )
    }
    
    private func runRepeat(
        repeatSteps: [Step]
    ) -> DIRepeatFunction<Process, Step, T> {
        return {
            createProcess,
            steps,
            onStart,
            onStartStep,
            onSuccessStep,
            onSuccess,
            onError in
            
            await DependencyInitializer(
                createProcess: createProcess ?? self.createProcess,
                steps: steps ?? repeatSteps,
                onStart: onStart ?? self.onStart,
                onStartStep: onStartStep ?? self.onStartStep,
                onSuccessStep: onSuccessStep ?? self.onSuccessStep,
                onSuccess: onSuccess ?? self.onSuccess,
                onError: onError ?? self.onError,
            ).run()
        }
    }
}
