import Foundation

public struct KillerTask: Sendable, Identifiable, Equatable, Clonable, Timestamped {
    public init(id: Int, body: String, createdAt: Date, updatedAt: Date, completedAt: Date? = nil, deletedAt: Date? = nil, parentID: Int? = nil) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.parentID = parentID
        
        self.instanceID = UUID()
    }
    
    public let instanceID: UUID
    
    public let id: Int
    public var body: String
    public var completedAt: Date?
    
    public var isComplete: Bool { self.completedAt != nil }
    
    public var parentID: Int?
    
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
}

public protocol RecursiveData: Identifiable where ID == Int {
    var parentID: Int? { get }
}

extension KillerTask: RecursiveData { }

public protocol Timestamped {
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
