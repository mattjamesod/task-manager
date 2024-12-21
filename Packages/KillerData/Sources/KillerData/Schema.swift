import Foundation
import AsyncAlgorithms
@preconcurrency import SQLite
import KillerModels

public protocol TableSchema {
    static var baseExpression: SQLite.Table { get }
    static var id: SQLite.Expression<UUID> { get }
    static var createdAt: SQLite.Expression<Date?> { get }
    static var updatedAt: SQLite.Expression<Date?> { get }
    static var deletedAt: SQLite.Expression<Date?> { get }
}

extension Database {
    public enum Schema {
        public enum Tasks: TableSchema {
            public static let baseExpression: SQLite.Table = Table("tasks")
            
            public static let id = SQLite.Expression<UUID>("id")
            public static let createdAt = SQLite.Expression<Date?>("createdAt")
            public static let updatedAt = SQLite.Expression<Date?>("updatedAt")
            public static let deletedAt = SQLite.Expression<Date?>("deletedAt")
            
            static let parentID = SQLite.Expression<UUID?>("parentID")
            static let body = SQLite.Expression<String>("body")
            static let completedAt = SQLite.Expression<Date?>("completedAt")
            
            static var create: String {
                self.baseExpression.create(ifNotExists: true, withoutRowid: true) {
                    $0.column(id, primaryKey: true)
                    $0.column(body, defaultValue: "")
                    $0.column(createdAt)
                    $0.column(updatedAt)
                    $0.column(completedAt, defaultValue: nil)
                    $0.column(deletedAt, defaultValue: nil)
                    $0.column(parentID, defaultValue: nil)
                    $0.foreignKey(parentID, references: baseExpression, id, delete: .cascade)
                }
            }
            
            static var drop: String {
                self.baseExpression.drop()
            }
        }
    }
}
