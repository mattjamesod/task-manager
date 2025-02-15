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
    
    enum ComparisonProperty: Int {
        case createdAt = 0
        case updatedAt = 1
        case deletedAt = 2
        case completedAt = 3
        case parentID = 4
        
//        var value: KeyPath<KillerCriterion, Optional<Any.Type>> {
//            switch self {
//            case .createdAt:
//                \.comparisonValueDate
//            case .updatedAt:
//                \.comparisonValueDate
//            case .deletedAt:
//                \.comparisonValueDate
//            case .completedAt:
//                \.comparisonValueDate
//            case .parentID:
//                \.comparisonValueInt
//            }
//        }
    }
    
    public let id: UUID
    
    public var createdAt: Date?
    public var updatedAt: Date?
    public var deletedAt: Date?
    
    public var kind: Kind
    public var comparisonProperty: ComparisonProperty
    public var comparisonValueInt: Int?
    public var comparisonValueDate: Date?
}
