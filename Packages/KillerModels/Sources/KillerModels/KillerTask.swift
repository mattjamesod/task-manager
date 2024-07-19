import Foundation

/// Represents a task in a SwiftUI view
public struct KillerTask: Sendable, Identifiable, Equatable, Clonable {
    public init(id: Int? = nil, body: String, createdAt: Date, updatedAt: Date, completedAt: Date? = nil, deletedAt: Date? = nil, parentID: Int? = nil) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.parentID = parentID
    }
    
    public let id: Int?
    public var body: String
    public var completedAt: Date?
    
    public var parentID: Int? // likewise, parent may not be shown in the view
    
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
}

public protocol Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self
    func cloned<each T>(suchThat properties: repeat WritableKeyPath<Self, each T>, are value: repeat each T) -> Self
}

public extension Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
    
    func cloned<each T>(suchThat properties: repeat WritableKeyPath<Self, each T>, are values: repeat each T) -> Self {
        var clone = self
        for (property, value) in repeat (each properties, each values) {
            clone[keyPath: property] = value
        }
        return clone
    }
}
