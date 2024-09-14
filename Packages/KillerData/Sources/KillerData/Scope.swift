@preconcurrency import SQLite
import Foundation
import KillerModels

extension Database {
    public struct Scope: KillerScopeProtocol, Sendable {
        public let id: Int
        public let name: String
        public let apply: @Sendable (SQLite.Table) -> SQLite.Table
        
        public let createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        
        let insertArguments: [SQLite.Setter] 
        
        public func compose(with other: Scope?) -> Scope {
            guard let other else { return self }
            
            return Scope(name: self.name, insertArguments: self.insertArguments + other.insertArguments) {
                other.apply(self.apply($0))
            }
        }
        
        fileprivate init(
            name: String,
            insertArguments: [Setter] = [],
            tableExpression: @escaping @Sendable (SQLite.Table) -> (SQLite.Table)
        ) {
            self.name = name
            self.insertArguments = insertArguments
            self.apply = tableExpression
            
            // TODO: make me come from the DB
            self.id = Int.random(in: 1..<99999)
            self.createdAt = Date.now
            self.updatedAt = Date.now
            self.deletedAt = nil
        }
        
        public static let allActiveTasks: Scope = .init(
            name: "Active",
            tableExpression: { base in
                let table = Schema.Tasks.tableExpression
                
                return base
                    .filter(table[Schema.Tasks.completedAt] == nil && table[Schema.Tasks.deletedAt] == nil)
                    .order(table[Schema.Tasks.createdAt].asc)
            }
        )
        
        public static let completedTasks: Scope = .init(
            name: "Completed",
            insertArguments: [
                Schema.Tasks.completedAt <- Date.now
            ],
            tableExpression: { base in
                let table = Schema.Tasks.tableExpression
                
                return base
                    .filter(table[Schema.Tasks.completedAt] != nil && table[Schema.Tasks.deletedAt] == nil)
                    .order(table[Schema.Tasks.createdAt].asc)
            }
        )
        
        public static let orphaned: Scope = .init(name: "Orphaned") { base in
            let tasks = Schema.Tasks.tableExpression
            let cte = Table("cte")
            
            return base
                .with(cte, as: base.select(Schema.Tasks.id))
                .join(.leftOuter, cte, on: tasks[Schema.Tasks.parentID] == cte[Schema.Tasks.id])
                .select(Schema.Tasks.tableExpression[*])
                .filter(cte[SQLite.Expression<Int?>("id")] == nil)
        }
        
        public static func children(of parentID: Int?) -> Scope {
            .init(
                name: "Children of \(parentID)",
                insertArguments: [
                    Schema.Tasks.parentID <- parentID
                ],
                tableExpression: { base in
                    let tasks = Schema.Tasks.tableExpression
                    return base.filter(tasks[Schema.Tasks.parentID] == parentID)
                }
            )
        }
        
        public static let deletedTasks: Scope = .init(
            name: "Deleted",
            insertArguments: [
                Schema.Tasks.deletedAt <- Date.now
            ], tableExpression: { base in
                base
                    .filter(Schema.Tasks.deletedAt != nil)
                    .order(Schema.Tasks.deletedAt.asc)
            }
        )
    }
}

extension Database.Scope: Equatable {
    public static func ==(lhs: Database.Scope, rhs: Database.Scope) -> Bool {
        lhs.id == rhs.id
    }
}
