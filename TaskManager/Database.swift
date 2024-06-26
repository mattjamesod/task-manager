import SwiftUI
import SQLite

enum DatabaseConnectionError: Error {
    case couldNotAccessDocumentsDirectory
    case couldNotCreateConnection(because: Error)
}

enum DatabaseError: Error {
    case couldNotEstablishConnection
    case couldNotCreateSchema
    case propertyDoesNotExist
}

protocol ModelSchema {
    static var tableExpression: SQLite.Table { get }
    static var id: SQLite.Expression<Int> { get }
}

protocol SchemaBacked {
    associatedtype SchemaType: ModelSchema
    static func create(from databaseRecord: SQLite.Row) throws -> Self
    static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value
    
    var id: Int? { get }
}

extension KillerTask: SchemaBacked {
    typealias SchemaType = Database.Schema.Tasks
    
    static func create(from databaseRecord: SQLite.Row) throws -> KillerTask {
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
    
    static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value {
        switch keyPath {
        case \.id: SchemaType.id as! SQLite.Expression<T>
        case \.body: SchemaType.body as! SQLite.Expression<T>
        case \.isCompleted: SchemaType.isCompleted as! SQLite.Expression<T>
        case \.isDeleted: SchemaType.isDeleted as! SQLite.Expression<T>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
}

extension Database {
    enum Query {
        case allActiveItems
        
        var tableExpression: SQLite.Table{
            switch self {
            case .allActiveItems: Schema.Tasks.tableExpression.filter(!Schema.Tasks.isCompleted && !Schema.Tasks.isDeleted)
            }
        }
    }
}

class DatabaseSetupHelper {
    private let schema: Database.SchemaDescription
    
    init(schema: Database.SchemaDescription) {
        self.schema = schema
    }
    
    func setup() throws(DatabaseError) -> Database {
        let schema = Database.SchemaDescription.userData
        let connectionManager = DatabaseConnectionManager(databaseName: schema.fileName)
        let connection: SQLite.Connection
        
        do {
            connection = try connectionManager.createConnection()
        }
        catch {
            // TODO: log connection error
            throw DatabaseError.couldNotEstablishConnection
        }
        
        return try Database(schema: schema, connection: connection)
    }
}

/// Actor to perform methods on a given SQLite Database, from a list of pre-defined database structures
/// Methods catch lower-level errors and log to analytiocs, then throw higher-level errors
actor Database {
    private let schema: SchemaDescription
    private let connection: Connection
    
    internal init(schema: Database.SchemaDescription, connection: SQLite.Connection) throws(DatabaseError) {
        self.schema = schema
        self.connection = connection
        
        do {
            try schema.create(connection: connection)
        }
        catch {
            throw DatabaseError.couldNotCreateSchema
        }
    }
    
    func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, query: Database.Query) -> [ModelType] {
        do {
            let records = try connection.prepare(query.tableExpression)
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return []
        }
    }
    
    @discardableResult
    func insert<ModelType: SchemaBacked, each T: SQLite.Value>(
        _ type: ModelType.Type, 
        setting properties: repeat KeyPath<ModelType, each T>,
        to values: repeat each T
    ) -> ModelType? {
        do {
            // no way to map over a parameter pack since you have to `repeat` them, so here
            // we use a slightly ugly loop to generate an array of property setters
            
            var setters: [Setter] = []
            
            for (property, value) in repeat (each properties, each values) {
                setters.append(try ModelType.getSchemaExpression(for: property) <- value)
            }
            
            let newId = try connection.run(
                ModelType.SchemaType.tableExpression.insert(setters)
            )
            
            return try connection.prepare(
                ModelType.SchemaType.tableExpression
                    .filter(Schema.Tasks.id == Int(newId))
            )
            .map(ModelType.create(from:))
            .first
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return nil
        }
    }
    
    /// Updates a specified property for a record matching the id of the given model.
    // TODO:  If the model has no matching record in the database, it is created with the updated value.
    func update<ModelType: SchemaBacked, PropertyType: SQLite.Value>(
        _ model: ModelType,
        suchThat path: KeyPath<ModelType, PropertyType>,
        is value: PropertyType)
    {
        do {
            guard let id = model.id else {
                return
            }
            
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.id == id)
                    .update(ModelType.getSchemaExpression(for: path) <- value)
            )
        }
        catch DatabaseError.propertyDoesNotExist {
            
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
}

extension EnvironmentValues {
    @Entry var database: Database? = nil
}

class DatabaseConnectionManager {
    // nil implies an in-memory db for testing
    private let databaseName: String?
    
    init(databaseName: String?) {
        self.databaseName = databaseName
    }
    
    func createConnection() throws(DatabaseConnectionError) -> Connection {
        guard let userDocumentsDir else {
            throw DatabaseConnectionError.couldNotAccessDocumentsDirectory
        }
        
        do {
            if let databaseName {
                return try Connection("\(userDocumentsDir)/\(databaseName).sqlite3")
            }
            else {
                return try Connection()
            }
        }
        catch {
            throw DatabaseConnectionError.couldNotCreateConnection(because: error)
        }
    }
    
    private var userDocumentsDir: String? {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
}

extension Database {
    enum SchemaDescription {
        case userData
        case testing
        
        var fileName: String? {
            switch self {
            case .userData: "user_data"
            case .testing: nil
            }
        }
        
        func create(connection: SQLite.Connection) throws {
            switch self {
            case .userData:
                try connection.run(Schema.Tasks.create)
            case .testing:
                try connection.run(Schema.Tasks.create)
            }
        }
        
        func destroy(connection: SQLite.Connection) throws {
            switch self {
            case .userData:
                try connection.run(Schema.Tasks.drop)
            case .testing:
                try connection.run(Schema.Tasks.drop)
            }
        }
    }
}

extension Database {
    enum Schema {
        enum Tasks: ModelSchema {
            static let tableExpression: SQLite.Table = Table("tasks")
            
            static let id = SQLite.Expression<Int>("id")
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
