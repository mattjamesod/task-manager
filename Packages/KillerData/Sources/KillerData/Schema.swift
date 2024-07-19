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

public protocol SchemaBacked: Sendable {
    associatedtype SchemaType: ModelSchema
    associatedtype MessageHandlerType: DatabaseMessageHandler
    
    static func create(from databaseRecord: SQLite.Row) throws -> Self
    static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value
    static func getSchemaExpression<T>(optional keyPath: KeyPath<Self, T?>) throws -> SQLite.Expression<T?> where T: SQLite.Value
    
    var id: Int? { get }
    static var messageHandler: MessageHandlerType { get }
}

extension Database {
    public enum Schema {
        public enum Tasks: ModelSchema {
            public static let tableExpression: SQLite.Table = Table("tasks")
            public static let id = SQLite.Expression<Int>("id")
            public static let createdAt = SQLite.Expression<Date>("createdAt")
            public static let updatedAt = SQLite.Expression<Date>("updatedAt")
            public static let deletedAt = SQLite.Expression<Date?>("deletedAt")
            
            static let body = SQLite.Expression<String>("body")
            static let completedAt = SQLite.Expression<Date?>("completedAt")
            static let parentID = SQLite.Expression<Int?>("parentID")
            
            static var create: String {
                self.tableExpression.create(ifNotExists: true) {
                    $0.column(id, primaryKey: .autoincrement)
                    $0.column(body)
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

extension KillerTask: SchemaBacked {
    public typealias SchemaType = Database.Schema.Tasks
    
    public static var messageHandler: KillerTaskMessageHandler { .instance }
    
    public static func create(from databaseRecord: SQLite.Row) throws -> KillerTask {
        do {
            return KillerTask(
                id: try databaseRecord.get(Database.Schema.Tasks.id),
                body: try databaseRecord.get(Database.Schema.Tasks.body),
                createdAt: try databaseRecord.get(Database.Schema.Tasks.createdAt),
                updatedAt: try databaseRecord.get(Database.Schema.Tasks.updatedAt),
                completedAt: try databaseRecord.get(Database.Schema.Tasks.completedAt),
                deletedAt: try databaseRecord.get(Database.Schema.Tasks.deletedAt),
                parentID: try databaseRecord.get(Database.Schema.Tasks.parentID),
                children: []
            )
        }
        catch {
            // TODO: log property error
            throw DatabaseError.propertyDoesNotExist
        }
    }
    
    public static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value {
        switch keyPath {
        case \.id: SchemaType.id as! SQLite.Expression<T>
        case \.body: SchemaType.body as! SQLite.Expression<T>
        case \.createdAt: SchemaType.createdAt as! SQLite.Expression<T>
        case \.updatedAt: SchemaType.updatedAt as! SQLite.Expression<T>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
    
    public static func getSchemaExpression<T>(optional keyPath: KeyPath<Self, T?>) throws -> SQLite.Expression<T?> where T: SQLite.Value {
        switch keyPath {
        case \.completedAt: SchemaType.completedAt as! SQLite.Expression<T?>
        case \.deletedAt: SchemaType.deletedAt as! SQLite.Expression<T?>
        case \.parentID: SchemaType.parentID as! SQLite.Expression<T?>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
}
