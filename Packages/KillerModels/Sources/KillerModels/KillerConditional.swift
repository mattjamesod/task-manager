import Foundation

public protocol AllowedConditionalType {
    var allowedComparators: [Comparator] { get }
}

extension Bool: AllowedConditionalType {
    public var allowedComparators: [Comparator] { [ .equals, .doesNotEqual ] }
}

extension Int: AllowedConditionalType {
    public var allowedComparators: [Comparator] { Comparator.allCases }
}

public enum Comparator: Int, CaseIterable {
    case lessThan = 0
    case greaterThan = 1
    case equals = 2
    case doesNotEqual = 3
}


public struct KillerConditional<T: AllowedConditionalType>: Identifiable, Timestamped {
    
    public var id: Int
    
//    public var operand: Operand
    public var comparator: Comparator
    
    // multiple Db columns for each type
    public var value: T
    
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
}
