import Foundation

public class TimeDispatcher {
    func diffTime(
        _ start: DispatchTime
    ) -> Double {
        let end = DispatchTime.now()
        let difference: UInt64 = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(difference)
    }
}
