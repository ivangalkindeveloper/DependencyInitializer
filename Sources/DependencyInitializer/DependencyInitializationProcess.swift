@MainActor
public protocol DependencyInitializationProcess: AnyObject, Sendable {
    associatedtype T
    
    var toContainer: T { get }
}
