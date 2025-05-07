// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@MainActor
public final class DependencyInitializer<Process: DIProcess, T: Sendable> where Process.T == T {
    // MARK: - Private properties

    private let createProcess: () -> Process
    private let steps: [DIStep]
    private let onStart: (() -> Void)?
    private let onStartStep: ((DIStep) -> Void)?
    private let onSuccessStep: ((DIStep, Double, Double) -> Void)?
    private let onSuccess: ((DIResult<Process, T>, Double) -> Void)?
    private let onError: ((Error, Process, DIStep, Double) -> Void)?

    // MARK: - Initialization

    public init(
        createProcess: @escaping () -> Process,
        steps: [DIStep],
        onStart: (() -> Void)? = nil,
        onStartStep: ((DIStep) -> Void)? = nil,
        onSuccessStep: ((DIStep, Double, Double) -> Void)? = nil,
        onSuccess: ((DIResult<Process, T>, Double) -> Void)? = nil,
        onError: ((Error, Process, DIStep, Double) -> Void)? = nil
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
    
    public func run() {
        assert(self.steps.isEmpty == false, "Step list can't be empty")
        
        let startTime = DispatchTime.now()
        let process: Process = self.createProcess()
        let context = self.getContext()
        
        if !context.syncSteps.isEmpty {
            for step in context.syncSteps {
                guard context.encounteredError == nil else {
                    break
                }
                
                self.executeSync(
                    process: process,
                    step: step,
                    context: context,
                    startTime: startTime
                )
            }
        }
        
        if !context.asyncSteps.isEmpty {
            Task {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for step in context.asyncSteps {
                        guard context.encounteredError == nil else {
                            return group.cancelAll()
                        }
                                                
                        group.addTask(
                            priority: step.taskPriority
                        ) {
                            await self.executeAsync(
                                process: process,
                                step: step,
                                context: context,
                                startTime: startTime
                            )
                        }
                    }
                            
                    try await group.waitForAll()
                    self.executeSuccess(
                        process: process,
                        context: context,
                        startTime: startTime
                    )
                }
            }
        } else {
            self.executeSuccess(
                process: process,
                context: context,
                startTime: startTime
            )
        }
    }
        
    // MARK: - Private methods
    
    private func executeSync(
        process: Process,
        step: SyncInitializationStep<Process>,
        context: Context<Process>,
        startTime: DispatchTime,
    ) {
        do {
            let stepStartTime = DispatchTime.now()
            try step.run(process)
            self.onSuccessStep?(
                step,
                self.endDispatchTime(stepStartTime),
                self.endDispatchTime(startTime)
            )
        } catch {
            guard context.encounteredError == nil else {
                return
            }
            
            context.encounteredError = error
            self.onError?(
                error,
                process,
                step,
                self.endDispatchTime(startTime)
            )
        }
    }
    
    private func executeAsync(
        process: Process,
        step: AsyncInitializationStep<Process>,
        context: Context<Process>,
        startTime: DispatchTime,
    ) async {
        do {
            let stepStartTime = DispatchTime.now()
            try await step.run(process)
            self.onSuccessStep?(
                step,
                self.endDispatchTime(stepStartTime),
                self.endDispatchTime(startTime)
            )
        } catch {
            guard context.encounteredError == nil else {
                return
            }
            
            context.encounteredError = error
            self.onError?(
                error,
                process,
                step,
                self.endDispatchTime(startTime)
            )
        }
    }
    
    private func executeSuccess(
        process: Process,
        context: Context<Process>,
        startTime: DispatchTime,
    ) {
        guard context.encounteredError == nil else {
            return
        }
        
        self.onSuccess?(
            DependencyInitializationResult<Process, T>(
                result: process.toResult,
                reinitializationStepList: context.repeatSteps,
                runRepeat: self.runRepeat(
                    repeatSteps: context.repeatSteps
                ),
            ),
            self.endDispatchTime(startTime)
        )
    }
    
    private func endDispatchTime(
        _ start: DispatchTime
    ) -> Double {
        let end = DispatchTime.now()
        let difference: UInt64 = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(difference)
    }
    
    private func getContext() -> Context<Process> {
        var syncSteps: [SyncInitializationStep<Process>] = []
        var asyncSteps: [AsyncInitializationStep<Process>] = []
        var repeatSteps: [DIStep] = []
        
        for step in self.steps {
            if let step = step as? SyncInitializationStep<Process> {
                syncSteps.append(step)
            }
            if let step = step as? AsyncInitializationStep<Process> {
                asyncSteps.append(step)
            }
            
            switch step.type {
            case .simple:
                break
            case .repeatable:
                repeatSteps.append(step)
            }
        }
        
        return Context<Process>(
            syncSteps: syncSteps,
            asyncSteps: asyncSteps,
            repeatSteps: repeatSteps,
        )
    }
    
    private func runRepeat(
        repeatSteps: [DIStep]
    ) -> DIRepeatCallback<Process, T> {
        return {
            createProcess,
                steps,
                onStart,
                onStartStep,
                onSuccessStep,
                onSuccess,
                onError in
            
            DependencyInitializer(
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
