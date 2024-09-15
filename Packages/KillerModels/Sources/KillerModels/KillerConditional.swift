import Foundation

public enum Comparator: Int {
    case lessThan = 0
    case greaterThan = 1
    case equals = 2
    case doesNotEqual = 3
}

public struct KillerConditional<ModelType, PropertyType: Comparable>: Identifiable, Timestamped {
    public var id: Int
    
    public var property: KeyPath<ModelType, PropertyType>
    public var comparator: Comparator
    public var comparatorValue: PropertyType
    
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
}
