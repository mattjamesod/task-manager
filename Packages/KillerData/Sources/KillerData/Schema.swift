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
    
    var id: Int? { get }
}

extension Database {
    public enum Schema {
        public enum Tasks: ModelSchema {
            public static let tableExpression: SQLite.Table = Table("tasks")
            public static let id = SQLite.Expression<Int>("id")
            static let body = SQLite.Expression<String>("body")
            static let isCompleted = SQLite.Expression<Bool>("isCompleted")
            static let isDeleted = SQLite.Expression<Bool>("isDeleted")
            
            static var create: String {
                self.tableExpression.create(ifNotExists: true) {
                    $0.column(Schema.Tasks.id, primaryKey: .autoincrement)
                    $0.column(Schema.Tasks.body)
                    $0.column(Schema.Tasks.isCompleted, defaultValue: false)
                    $0.column(Schema.Tasks.isDeleted, defaultValue: false)
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
                isCompleted: try databaseRecord.get(Database.Schema.Tasks.isCompleted),
                isDeleted: try databaseRecord.get(Database.Schema.Tasks.isDeleted)
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
        case \.isCompleted: SchemaType.isCompleted as! SQLite.Expression<T>
        case \.isDeleted: SchemaType.isDeleted as! SQLite.Expression<T>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
}
