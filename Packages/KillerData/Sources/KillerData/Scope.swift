@preconcurrency import SQLite
import Foundation
import KillerModels

extension Database {
    public struct Scope: Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let symbolName: String
        public let allowsTaskEntry: Bool
        
        public let apply: @Sendable (SQLite.Table) -> (SQLite.Table)
        public let applyToModel: @Sendable (KillerTask) -> (KillerTask)
        
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
        
        fileprivate init(
            name: String,
            symbolName: String = "list.bullet.indent",
            allowsTaskEntry: Bool = true,
            insertArguments: [Setter] = [],
            tableExpression: @escaping @Sendable (SQLite.Table) -> (SQLite.Table),
            modelScopingRules: @escaping @Sendable (KillerTask) -> (KillerTask)
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
        
        public static let allActiveTasks: Scope = .init(
            name: "Active",
            tableExpression: { base in
                let table = Schema.Tasks.baseExpression
                
                return base
                    .filter(table[Schema.Tasks.completedAt] == nil && table[Schema.Tasks.deletedAt] == nil)
                    .order(table[Schema.Tasks.createdAt].asc)
            },
            modelScopingRules: { base in
                base.cloned(suchThat: \.completedAt, \.deletedAt, are: nil, nil)
            }
        )
        
        public static let completedTasks: Scope = .init(
            name: "Completed",
            symbolName: "checkmark",
            insertArguments: [
                Schema.Tasks.completedAt <- Date.now
            ],
            tableExpression: { base in
                let table = Schema.Tasks.baseExpression
                
                return base
                    .filter(table[Schema.Tasks.completedAt] != nil && table[Schema.Tasks.deletedAt] == nil)
                    .order(table[Schema.Tasks.createdAt].asc)
            },
            modelScopingRules: { base in
                base.cloned(suchThat: \.completedAt, \.deletedAt, are: Date.now, nil)
            }
        )
        
        public static let orphaned: Scope = .init(
            name: "Orphaned",
            tableExpression: { base in
                let tasks = Schema.Tasks.baseExpression
                let cte = Table("cte")
                
                return base
                    .with(cte, as: base.select(Schema.Tasks.id))
                    .join(.leftOuter, cte, on: tasks[Schema.Tasks.parentID] == cte[Schema.Tasks.id])
                    .select(Schema.Tasks.baseExpression[*])
                    .filter(cte[SQLite.Expression<Int?>("id")] == nil)
                },
            modelScopingRules: { base in
                // not all tasks returned by the query will have this property,
                // but this gaurentees a new task created in this context will match
                base.cloned(suchThat: \.parentID, is: nil)
            }
        )
        
        public static func children(of parentID: UUID?) -> Scope {
            .init(
                name: "Children of \(parentID)",
                insertArguments: [
                    Schema.Tasks.parentID <- parentID
                ],
                tableExpression: { base in
                    let tasks = Schema.Tasks.baseExpression
                    return base.filter(tasks[Schema.Tasks.parentID] == parentID)
                },
                modelScopingRules: { base in
                    base.cloned(suchThat: \.parentID, is: parentID)
                }
            )
        }
        
        public static let deletedTasks: Scope = .init(
            name: "Deleted",
            symbolName: "trash",
            allowsTaskEntry: false,
            insertArguments: [
                Schema.Tasks.deletedAt <- Date.now
            ],
            tableExpression: { base in
                base
                    .filter(Schema.Tasks.deletedAt != nil)
                    .order(Schema.Tasks.deletedAt.asc)
            },
            modelScopingRules: { base in
                base.cloned(suchThat: \.deletedAt, is: Date.now)
            }
        )
    }
}

extension Database.Scope: Equatable {
    public static func ==(lhs: Database.Scope, rhs: Database.Scope) -> Bool {
        lhs.id == rhs.id
    }
}

extension Database.Scope: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
