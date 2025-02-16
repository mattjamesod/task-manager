@preconcurrency import SQLite
import Foundation
import KillerModels

extension Database {
    public struct Scope<Model>: Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let symbolName: String
        public let allowsTaskEntry: Bool
        
        public let apply: @Sendable (SQLite.Table) -> (SQLite.Table)
        public let applyToModel: @Sendable (Model) -> (Model)
        
        public let createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        
        let insertProperties: [SQLite.Setter]
        
        public func compose(with other: Scope?) -> Scope {
            guard let other else { return self }
            
            return Scope(
                name: self.name,
                allowsTaskEntry: self.allowsTaskEntry && other.allowsTaskEntry,
                insertArguments: self.insertProperties + other.insertProperties,
                tableExpression: {
                    other.apply(self.apply($0))
                },
                modelScopingRules: {
                    other.applyToModel(self.applyToModel($0))
                }
            )
        }
        
        init(
            name: String,
            symbolName: String = "list.bullet.indent",
            allowsTaskEntry: Bool = true,
            insertArguments: [Setter] = [],
            tableExpression: @escaping @Sendable (SQLite.Table) -> (SQLite.Table),
            modelScopingRules: @escaping @Sendable (Model) -> (Model)
        ) {
            self.name = name
            self.symbolName = symbolName
            self.allowsTaskEntry = allowsTaskEntry
            self.insertProperties = insertArguments
            self.apply = tableExpression
            self.applyToModel = modelScopingRules
            
            // TODO: make me come from the DB
            self.id = Int.random(in: 1..<99999)
            self.createdAt = Date.now
            self.updatedAt = Date.now
            self.deletedAt = nil
        }
        
        public init(
            tableExpression: @escaping @Sendable (SQLite.Table) -> (SQLite.Table)
        ) {
            self.name = "Custom Scope"
            self.symbolName = "list.bullet.indent"
            self.allowsTaskEntry = true
            self.insertProperties = []
            self.apply = tableExpression
            self.applyToModel = { $0 }
            
            // TODO: make me come from the DB
            self.id = Int.random(in: 1..<99999)
            self.createdAt = Date.now
            self.updatedAt = Date.now
            self.deletedAt = nil
        }
    }
}

extension Database.Scope: Equatable where Model: Identifiable {
    public static func ==(lhs: Database.Scope<Model>, rhs: Database.Scope<Model>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Database.Scope: Hashable where Model: Identifiable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
