import Foundation

@MainActor
final class StepCallbacksRelay<Process: DIProcess>: @unchecked Sendable {
    let onSuccessStep: ((DIStep, Double, Double) -> Void)?
    let onError: ((Error, Process, DIStep, Double) -> Void)?
    let diffTime: (DispatchTime) -> Double

    init(
        onSuccessStep: ((DIStep, Double, Double) -> Void)?,
        onError: ((Error, Process, DIStep, Double) -> Void)?,
        diffTime: @escaping (DispatchTime) -> Double
    ) {
        self.onSuccessStep = onSuccessStep
        self.onError = onError
        self.diffTime = diffTime
    }

    @MainActor
    func reportSuccess(
        step: DIStep,
        stepStart: DispatchTime,
        contextStart: DispatchTime
    ) {
        self.onSuccessStep?(
            step,
            self.diffTime(stepStart),
            self.diffTime(contextStart)
        )
    }


    func reportError(
        context: Context<Process>,
        error: Error,
        step: DIStep
    ) {
        guard context.error == nil else {
            return
        }
        context.catchError(error)
        self.onError?(error, context.process, step, self.diffTime(context.startTime))
    }
}
