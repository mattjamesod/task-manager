import Foundation
import SQLite
import KillerModels

public protocol ModelSchema {
    static var tableExpression: SQLite.Table { get }
    static var id: SQLite.Expression<Int> { get }
}

public protocol SchemaBacked {
    associatedtype SchemaType: ModelSchema
    static func create(from databaseRecord: SQLite.Row) throws -> Self
    static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value
    static func getSchemaExpression<T>(optional keyPath: KeyPath<Self, T?>) throws -> SQLite.Expression<T?> where T: SQLite.Value
    
    var id: Int? { get }
}

extension Database {
    public enum Schema {
        public enum Tasks: ModelSchema {
            public static let tableExpression: SQLite.Table = Table("tasks")
            public static let id = SQLite.Expression<Int>("id")
            static let body = SQLite.Expression<String>("body")
            static let createdAt = SQLite.Expression<Date>("createdAt")
            static let updatedAt = SQLite.Expression<Date>("updatedAt")
            static let completedAt = SQLite.Expression<Date?>("completedAt")
            static let deletedAt = SQLite.Expression<Date?>("deletedAt")
            
            static var create: String {
                self.tableExpression.create(ifNotExists: true) {
                    $0.column(Schema.Tasks.id, primaryKey: .autoincrement)
                    $0.column(Schema.Tasks.body)
                    $0.column(Schema.Tasks.createdAt, defaultValue: Date.now)
                    $0.column(Schema.Tasks.updatedAt, defaultValue: Date.now)
                    $0.column(Schema.Tasks.completedAt, defaultValue: nil)
                    $0.column(Schema.Tasks.deletedAt, defaultValue: nil)
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
    
    public static func create(from databaseRecord: SQLite.Row) throws -> KillerTask {
        do {
            return KillerTask(
                id: try databaseRecord.get(Database.Schema.Tasks.id),
                body: try databaseRecord.get(Database.Schema.Tasks.body),
                createdAt: try databaseRecord.get(Database.Schema.Tasks.createdAt),
                updatedAt: try databaseRecord.get(Database.Schema.Tasks.updatedAt),
                completedAt: try databaseRecord.get(Database.Schema.Tasks.completedAt),
                deletedAt: try databaseRecord.get(Database.Schema.Tasks.deletedAt)
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
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
}
