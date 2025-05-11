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
}

// MARK: - Public methods

public extension DependencyInitializer {
    func run() {
        assert(
            self.steps.isEmpty == false,
            "Step list can't be empty"
        )
        
        let context: Context = self.getContext()
        self.onStart?()
        
        self.executeSteps(
            context: context,
        )
        
        self.executeAsyncSteps(
            context: context,
        )
    }
}

// MARK: - Private methods

private extension DependencyInitializer {
    func getContext() -> Context<Process> {
        let process = self.createProcess()
        var steps: [InitializationStep<Process>] = []
        var asyncSteps: [AsyncInitializationStep<Process>] = []
        var repeatSteps: [DIStep] = []
        
        for step in self.steps {
            if let step = step as? InitializationStep<Process> {
                steps.append(step)
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
            process: process,
            steps: steps,
            asyncSteps: asyncSteps,
            repeatSteps: repeatSteps
        )
    }
    
    func executeSteps(
        context: Context<Process>,
    ) {
        guard !context.steps.isEmpty else {
            return
        }
        
        var currentStep: InitializationStep = context.steps.first!
        do {
            for step in context.steps {
                currentStep = step
                let stepStartTime = DispatchTime.now()
                try step.run(context.process)
                self.onSuccessStep?(
                    step,
                    self.endDispatchTime(stepStartTime),
                    self.endDispatchTime(context.startTime)
                )
            }
                
            if context.asyncSteps.isEmpty {
                return self.executeSuccess(
                    context: context
                )
            }
        } catch {
            context.catchError(error)
            self.onError?(
                error,
                context.process,
                currentStep,
                self.endDispatchTime(context.startTime)
            )
        }
    }
    
    func executeAsyncSteps(
        context: Context<Process>,
    ) {
        guard !context.asyncSteps.isEmpty, context.error == nil else {
            return
        }
        
        Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for step in context.asyncSteps {
                    guard context.error == nil else {
                        return group.cancelAll()
                    }
                        
                    group.addTask(
                        priority: step.taskPriority
                    ) {
                        await self.executeAsync(
                            context: context,
                            step: step
                        )
                    }
                }
                    
                try await group.waitForAll()
                self.executeSuccess(
                    context: context
                )
            }
        }
    }
    
    func executeAsync(
        context: Context<Process>,
        step: AsyncInitializationStep<Process>
    ) async {
        do {
            let stepStartTime = DispatchTime.now()
            try await step.run(context.process)
            self.onSuccessStep?(
                step,
                self.endDispatchTime(stepStartTime),
                self.endDispatchTime(context.startTime)
            )
        } catch {
            guard context.error == nil else {
                return
            }
            
            context.catchError(error)
            self.onError?(
                error,
                context.process,
                step,
                self.endDispatchTime(context.startTime)
            )
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
                reinitializationStepList: context.repeatSteps,
                runRepeat: self.runRepeat(
                    context: context
                ),
            ),
            self.endDispatchTime(context.startTime)
        )
    }
    
    func endDispatchTime(
        _ start: DispatchTime
    ) -> Double {
        let end = DispatchTime.now()
        let difference: UInt64 = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(difference)
    }
    
    func runRepeat(
        context: Context<Process>,
    ) -> DIRepeatCallback<Process, T> {
        {
            createProcess,
                steps,
                onStart,
                onStartStep,
                onSuccessStep,
                onSuccess,
                onError in
            
            DependencyInitializer(
                createProcess: createProcess ?? self.createProcess,
                steps: steps ?? context.repeatSteps,
                onStart: onStart ?? self.onStart,
                onStartStep: onStartStep ?? self.onStartStep,
                onSuccessStep: onSuccessStep ?? self.onSuccessStep,
                onSuccess: onSuccess ?? self.onSuccess,
                onError: onError ?? self.onError,
            ).run()
        }
    }
}
