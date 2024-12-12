import Foundation
import CloudKit

public struct KillerTask: Sendable, Identifiable, Equatable, Clonable, Timestamped {
    public init(
        id: UUID,
        body: String,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil,
        deletedAt: Date? = nil,
        parentID: UUID? = nil
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.deletedAt = deletedAt
        self.parentID = parentID
        
        self.instanceID = UUID()
    }
    
    /// the (auto-incrementing, sequantial) ID of the task in the local & cloud databases
    /// used as the model's ID for SwiftUI rendering purposes
    public let id: UUID
    
    /// the ID of the instance of the task. used by SwiftUI's .id method sometimes
    /// when a view should re-render after a DB update
    ///
    /// yes, I know this breaks the SwiftUI model. See comment in TaskCompleteCheckbox.swift
    public let instanceID: UUID
    
    public var body: String
    public var completedAt: Date?
    
    public var isComplete: Bool { self.completedAt != nil }
    
    public var parentID: UUID?
    
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
}

public protocol RecursiveData: Identifiable {
    var parentID: Self.ID? { get }
}

extension KillerTask: RecursiveData { }

public protocol Timestamped {
    var createdAt: Date { get }
    var updatedAt: Date { get set }
    var deletedAt: Date? { get set }
}
