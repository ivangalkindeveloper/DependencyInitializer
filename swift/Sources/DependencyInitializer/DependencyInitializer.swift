// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@MainActor
public final class DependencyInitializer<Process: DIProcess, T: Sendable>: TimeDispatcher where Process.T == T {
    // MARK: - Private properties
    
    private let createProcess: () -> Process
    private let stepSets: [StepSet<Process>]
    private let onStart: (() -> Void)?
    private let onStartStep: ((DIStep) -> Void)?
    private let onSuccessStep: ((DIStep, Double, Double) -> Void)?
    private let onSuccess: ((DIResult<Process, T>, Double) -> Void)?
    private let onError: ((Error, Process, DIStep, Double) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        createProcess: @escaping () -> Process,
        stepSets: [StepSet<Process>] = [],
        onStart: (() -> Void)? = nil,
        onStartStep: ((DIStep) -> Void)? = nil,
        onSuccessStep: ((DIStep, Double, Double) -> Void)? = nil,
        onSuccess: ((DIResult<Process, T>, Double) -> Void)? = nil,
        onError: ((Error, Process, DIStep, Double) -> Void)? = nil
    ) {
        self.createProcess = createProcess
        self.stepSets = stepSets
        self.onStart = onStart
        self.onStartStep = onStartStep
        self.onSuccessStep = onSuccessStep
        self.onSuccess = onSuccess
        self.onError = onError
    }
}

// MARK: - Public methods

public extension DependencyInitializer {
    func run() async {
        assert(
            !self.stepSets.isEmpty,
            "Step sets can't be empty"
        )
        
        let context: Context = self.getContext()
        self.onStart?()
        
        for stepSet in self.stepSets {
            guard context.error == nil else {
                break
            }
            
            switch stepSet.kind {
            case .sync(let steps):
                self.runSyncSteps(
                    context: context,
                    steps: steps
                )
            case .async(let steps):
                await self.runAsyncSteps(
                    context: context,
                    steps: steps
                )
            }
        }
        
        self.executeSuccess(
            context: context
        )
    }
}

// MARK: - Private methods
private extension DependencyInitializer {
    func getContext() -> Context<Process> {
        let process: Process = self.createProcess()
        let repeatStepSets: [StepSet<Process>] = self.stepSets.compactMap { $0.repeatable }
        
        return Context<Process>(
            process: process,
            repeatStepSets: repeatStepSets,
        )
    }
    
    func runSyncSteps(
        context: Context<Process>,
        steps: [SyncInitializationStep<Process>]
    ) {
        guard !steps.isEmpty else {
            return
        }
        
        var currentStep: SyncInitializationStep = steps.first!
        do {
            for step in steps {
                currentStep = step
                let stepStartTime = DispatchTime.now()
                self.onStartStep?(step)
                try step.run(context.process)
                self.onSuccessStep?(
                    step,
                    self.diffTime(stepStartTime),
                    self.diffTime(context.startTime)
                )
            }
        } catch {
            context.catchError(error)
            self.onError?(
                error,
                context.process,
                currentStep,
                self.diffTime(context.startTime)
            )
        }
    }
    
    func runAsyncSteps(
        context: Context<Process>,
        steps: [AsyncInitializationStep<Process>]
    ) async {
        guard !steps.isEmpty, context.error == nil else {
            return
        }
        
        let relay = StepCallbacksRelay<Process>(
            onSuccessStep: self.onSuccessStep,
            onError: self.onError,
            diffTime: { self.diffTime($0) }
        )
        try! await withThrowingTaskGroup(of: Void.self) { group in
            for step in steps {
                guard context.error == nil else {
                    return group.cancelAll()
                }
                
                self.onStartStep?(step)
                group.addTask(
                    priority: step.taskPriority
                ) {
                    await Self.runAsyncStep(
                        context: context,
                        step: step,
                        relay: relay
                    )
                }
            }
                
            try await group.waitForAll()
        }
    }
    
    nonisolated static func runAsyncStep(
        context: Context<Process>,
        step: AsyncInitializationStep<Process>,
        relay: StepCallbacksRelay<Process>
    ) async {
        do {
            let stepStartTime = DispatchTime.now()
            try await step.run(context.process)
            await MainActor.run {
                relay.reportSuccess(
                    step: step,
                    stepStart: stepStartTime,
                    contextStart: context.startTime
                )
            }
        } catch {
            await MainActor.run {
                relay.reportError(
                    context: context,
                    error: error,
                    step: step
                )
            }
        }
    }
    
    func executeSuccess(
        context: Context<Process>,
    ) {
        guard context.error == nil else {
            return
        }
        
        self.onSuccess?(
            DependencyInitializationResult<Process, T>(
                container: context.process.toContainer,
                repeatStepSets: context.repeatStepSets,
                runRepeat: self.runRepeat(
                    context: context
                ),
            ),
            self.diffTime(context.startTime)
        )
    }
    
    func runRepeat(
        context: Context<Process>,
    ) -> DIRepeatCallback<Process, T> {
        {
            createProcess,
            stepSets,
            onStart,
            onStartStep,
            onSuccessStep,
            onSuccess,
            onError in
            
            await DependencyInitializer(
                createProcess: createProcess ?? self.createProcess,
                stepSets: stepSets ?? self.stepSets,
                onStart: onStart ?? self.onStart,
                onStartStep: onStartStep ?? self.onStartStep,
                onSuccessStep: onSuccessStep ?? self.onSuccessStep,
                onSuccess: onSuccess ?? self.onSuccess,
                onError: onError ?? self.onError,
            ).run()
        }
    }
}
