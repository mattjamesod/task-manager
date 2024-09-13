import Foundation

// A scope is a way to read and write to a data collection in a custom manner
//
// The user/the program can define a set of filters on the data, and the scope
// knows how to create new data that will match those filters

public protocol KillerScopeProtocol: Identifiable, Timestamped {
    var id: Int { get }
    var name: String { get }
    
    associatedtype ScopedData
    
    var apply: @Sendable (ScopedData) -> ScopedData { get }
    func compose(with other: Self?) -> Self
}


public extension Optional where Wrapped: KillerScopeProtocol {
    func compose(with other: Wrapped?) -> Wrapped? {
        guard let other else { return self }
        guard let foundSelf = self else { return other }
        
        return foundSelf.compose(with: other)
    }
}
