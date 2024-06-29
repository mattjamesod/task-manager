import Foundation

public struct KillerTask: Identifiable, Equatable, Clonable {
    public init(id: Int? = nil, body: String, createdAt: Date, updatedAt: Date, completedAt: Date? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
    }
    
    public let id: Int?
    public var body: String
    public var createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var deletedAt: Date?
}

protocol Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self
}

extension Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
}
