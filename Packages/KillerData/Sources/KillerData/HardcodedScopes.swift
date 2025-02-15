@preconcurrency import SQLite
import Foundation
import KillerModels

public struct HardcodedScopes {
    typealias TaskSchema = Database.Schema.Tasks
    
    public static let allActiveTasks: Database.Scope = .init(
        name: "Active",
        tableExpression: { base in
            let table = TaskSchema.baseExpression
            
            return base
                .filter(table[TaskSchema.completedAt] == nil && table[TaskSchema.deletedAt] == nil)
                .order(table[TaskSchema.createdAt].asc)
        },
        modelScopingRules: { base in
            base.cloned(suchThat: \.completedAt, \.deletedAt, are: nil, nil)
        }
    )
    
    public static let completedTasks: Database.Scope = .init(
        name: "Completed",
        symbolName: "checkmark",
        allowsTaskEntry: false,
        insertArguments: [
            TaskSchema.completedAt <- Date.now
        ],
        tableExpression: { base in
            let table = TaskSchema.baseExpression
            
            return base
                .filter(table[TaskSchema.completedAt] != nil && table[TaskSchema.deletedAt] == nil)
                .order(table[TaskSchema.createdAt].asc)
        },
        modelScopingRules: { base in
            base.cloned(suchThat: \.completedAt, \.deletedAt, are: Date.now, nil)
        }
    )
    
    public static let orphaned: Database.Scope = .init(
        name: "Orphaned",
        tableExpression: { base in
            let tasks = TaskSchema.baseExpression
            let cte = Table("cte")
            
            return base
                .with(cte, as: base.select(TaskSchema.id))
                .join(.leftOuter, cte, on: tasks[TaskSchema.parentID] == cte[TaskSchema.id])
                .select(TaskSchema.baseExpression[*])
                .filter(cte[SQLite.Expression<Int?>("id")] == nil)
            },
        modelScopingRules: { base in
            // not all tasks returned by the query will have this property,
            // but this gaurentees a new task created in this context will match
            base.cloned(suchThat: \.parentID, is: nil)
        }
    )
    
    public static func children(of parentID: UUID?) -> Database.Scope {
        .init(
            name: "Children of \(parentID)",
            insertArguments: [
                TaskSchema.parentID <- parentID
            ],
            tableExpression: { base in
                let tasks = TaskSchema.baseExpression
                return base.filter(tasks[TaskSchema.parentID] == parentID)
            },
            modelScopingRules: { base in
                base.cloned(suchThat: \.parentID, is: parentID)
            }
        )
    }
    
    public static let deletedTasks: Database.Scope = .init(
        name: "Deleted",
        symbolName: "trash",
        allowsTaskEntry: false,
        insertArguments: [
            TaskSchema.deletedAt <- Date.now
        ],
        tableExpression: { base in
            base
                .filter(TaskSchema.deletedAt != nil)
                .order(TaskSchema.deletedAt.asc)
        },
        modelScopingRules: { base in
            base.cloned(suchThat: \.deletedAt, is: Date.now)
        }
    )
}
