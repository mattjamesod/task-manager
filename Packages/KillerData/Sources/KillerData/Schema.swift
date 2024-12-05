import Foundation
import AsyncAlgorithms
@preconcurrency import SQLite
import KillerModels

public protocol ModelSchema {
    static var tableExpression: SQLite.Table { get }
    static var id: SQLite.Expression<Int> { get }
    static var createdAt: SQLite.Expression<Date> { get }
    static var updatedAt: SQLite.Expression<Date> { get }
    static var deletedAt: SQLite.Expression<Date?> { get }
}

extension Database {
    public enum Schema {
        public enum Tasks: ModelSchema {
            public static let tableExpression: SQLite.Table = Table("tasks")
            public static let id = SQLite.Expression<Int>("id")
            public static let cloudID = SQLite.Expression<UUID>("cloudID")
            public static let createdAt = SQLite.Expression<Date>("createdAt")
            public static let updatedAt = SQLite.Expression<Date>("updatedAt")
            public static let deletedAt = SQLite.Expression<Date?>("deletedAt")
            
            static let parentID = SQLite.Expression<Int?>("parentID")
            
            static let body = SQLite.Expression<String>("body")
            static let completedAt = SQLite.Expression<Date?>("completedAt")
            
            static var create: String {
                self.tableExpression.create(ifNotExists: true) {
                    $0.column(id, primaryKey: .autoincrement)
                    $0.column(cloudID)
                    $0.column(body, defaultValue: "")
                    $0.column(createdAt)
                    $0.column(updatedAt)
                    $0.column(completedAt, defaultValue: nil)
                    $0.column(deletedAt, defaultValue: nil)
                    $0.column(parentID, defaultValue: nil)
                    $0.foreignKey(parentID, references: tableExpression, id, delete: .cascade)
                }
            }
            
            static var drop: String {
                self.tableExpression.drop()
            }
        }
    }
}
