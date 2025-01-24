import Foundation

struct KillerCriterion: Sendable, Identifiable, Timestamped {
    enum Kind: Int {
        case equal = 0
        case notEqual = 1
        case greaterThan = 2
        case lessThan = 3
        case containsString = 4
        case timeOfDay = 5
        case all = 6
        case any = 7
        case none = 8
        case orphaned = 9
    }
    
    public let id: UUID
    
    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    public var kind: Kind
    public var comparisonPropertyKey: Int
    
//    public var comparisonProperty: ModelType.ComparisonProperty
}

protocol CriterionApplicable {
    associatedtype ComparisonProperty
    
    
}
