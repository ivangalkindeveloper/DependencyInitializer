// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

@MainActor
public final class DependencyInitializer<Process: DIProcess, T: Sendable>: TimeDispatcher where Process.T == T {
    // MARK: - Private properties
    
    private let createProcess: () -> Process
    private let preSyncSteps: [SyncInitializationStep<Process>]
    private let asyncSteps: [AsyncInitializationStep<Process>]
    private let postSyncSteps: [SyncInitializationStep<Process>]
    private let onStart: (() -> Void)?
    private let onStartStep: ((DIStep) -> Void)?
    private let onSuccessStep: ((DIStep, Double, Double) -> Void)?
    private let onSuccess: ((DIResult<Process, T>, Double) -> Void)?
    private let onError: ((Error, Process, DIStep, Double) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        createProcess: @escaping () -> Process,
        preSyncSteps: [SyncInitializationStep<Process>] = [],
        asyncSteps: [AsyncInitializationStep<Process>] = [],
        postSyncSteps: [SyncInitializationStep<Process>] = [],
        onStart: (() -> Void)? = nil,
        onStartStep: ((DIStep) -> Void)? = nil,
        onSuccessStep: ((DIStep, Double, Double) -> Void)? = nil,
        onSuccess: ((DIResult<Process, T>, Double) -> Void)? = nil,
        onError: ((Error, Process, DIStep, Double) -> Void)? = nil
    ) {
        self.createProcess = createProcess
        self.preSyncSteps = preSyncSteps
        self.asyncSteps = asyncSteps
        self.postSyncSteps = postSyncSteps
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
            !self.preSyncSteps.isEmpty || !self.asyncSteps.isEmpty || !self.postSyncSteps.isEmpty,
            "Step lists can't be empty"
        )
        
        let context: Context = self.getContext()
        self.onStart?()
        
        self.runSyncSteps(
            context: context,
            steps: self.preSyncSteps,
        )
        
        await self.runAsyncSteps(
            context: context,
        )
        
        self.runSyncSteps(
            context: context,
            steps: self.postSyncSteps,
        )
    }
}

// MARK: - Private methods
private extension DependencyInitializer {
    func getContext() -> Context<Process> {
        let process = self.createProcess()
        var repeatPreSyncSteps: [SyncInitializationStep<Process>] = []
        var repeatAsyncSteps: [AsyncInitializationStep<Process>] = []
        var repeatPostSyncSteps: [SyncInitializationStep<Process>] = []
        
        for step in self.preSyncSteps {
            switch step.type {
            case .simple:
                break
            case .repeatable:
                repeatPreSyncSteps.append(step)
            }
        }
        for step in self.asyncSteps {
            switch step.type {
            case .simple:
                break
            case .repeatable:
                repeatAsyncSteps.append(step)
            }
        }
        for step in self.postSyncSteps {
            switch step.type {
            case .simple:
                break
            case .repeatable:
                repeatPostSyncSteps.append(step)
            }
        }
        
        return Context<Process>(
            process: process,
            //
            repeatPreSyncSteps: repeatPreSyncSteps,
            repeatAsyncSteps: repeatAsyncSteps,
            repeatPostSyncSteps: repeatPostSyncSteps,
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
    ) async {
        guard !self.asyncSteps.isEmpty, context.error == nil else {
            return
        }
        
        let relay = StepCallbacksRelay<Process>(
            onSuccessStep: self.onSuccessStep,
            onError: self.onError,
            diffTime: { self.diffTime($0) }
        )
        try! await withThrowingTaskGroup(of: Void.self) { group in
            for step in self.asyncSteps {
                guard context.error == nil else {
                    return group.cancelAll()
                }
                    
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
            self.executeSuccess(
                context: context
            )
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
                repeatPreSyncSteps: context.repeatPreSyncSteps,
                repeatAsyncSteps: context.repeatAsyncSteps,
                repeatPostSyncSteps: context.repeatPostSyncSteps,
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
            preSyncSteps,
            asyncSteps,
            postSyncSteps,
            onStart,
            onStartStep,
            onSuccessStep,
            onSuccess,
            onError in
            
            await DependencyInitializer(
                createProcess: createProcess ?? self.createProcess,
                preSyncSteps: preSyncSteps ?? self.preSyncSteps,
                asyncSteps: asyncSteps ?? self.asyncSteps,
                postSyncSteps: postSyncSteps ?? self.postSyncSteps,
                onStart: onStart ?? self.onStart,
                onStartStep: onStartStep ?? self.onStartStep,
                onSuccessStep: onSuccessStep ?? self.onSuccessStep,
                onSuccess: onSuccess ?? self.onSuccess,
                onError: onError ?? self.onError,
            ).run()
        }
    }
}
