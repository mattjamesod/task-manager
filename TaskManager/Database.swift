import SwiftUI
import SQLite

enum DatabaseConnectionError: Error {
    case couldNotAccessDocumentsDirectory
    case couldNotCreateConnection(because: Error)
}

enum DatabaseError: Error {
    case couldNotConnect
}

extension KillerTask {
    static func create(from databaseRecord: SQLite.Row) -> KillerTask {
        KillerTask(
            id: databaseRecord[Database.Schema.Tasks.id],
            body: databaseRecord[Database.Schema.Tasks.body],
            isCompleted: databaseRecord[Database.Schema.Tasks.isCompleted],
            isDeleted: databaseRecord[Database.Schema.Tasks.isDeleted]
        )
    }
}

/// Actor to perform methods on a given SQLite Database, from a list of pre-defined database structures
/// Methods catch lower-level errors and log to analytiocs, then throw higher-level errors
actor Database {
    private let schema: SchemaDescription
    private let connectionManager: ConnectionManager
    private var connection: Connection { connectionManager.activeConnection! }
    
    init(schema: Database.SchemaDescription) {
        self.schema = schema
        self.connectionManager = ConnectionManager(databaseName: schema.fileName)
    }
    
    func connect() throws {
        do {
            try self.connectionManager.createConnection()
            try schema.create(connection: connectionManager.activeConnection!)
        }
        catch DatabaseConnectionError.couldNotAccessDocumentsDirectory {
            // log the error to some analytics software
            
            throw DatabaseError.couldNotConnect
        }
        catch DatabaseConnectionError.couldNotCreateConnection(let rootError) {
            // log the *root* error to some analytics software
            
            throw DatabaseError.couldNotConnect
        }
    }
    
    func fetchTasks() -> [KillerTask] {
        do {
            let records = try connection.prepare(
                Schema.Tasks.tableExpression
                    .filter(!Schema.Tasks.isCompleted)
                    .filter(!Schema.Tasks.isDeleted)
            )
            
            return records.map(KillerTask.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return []
        }
    }
    
    func newTask() -> KillerTask? {
        do {
            let newTask = KillerTask(id: newId(), body: "I am a brand new baby task")
            
            try connection.run(
                Schema.Tasks.tableExpression.insert(
                    Schema.Tasks.id <- newTask.id,
                    Schema.Tasks.body <- newTask.body,
                    Schema.Tasks.isCompleted <- newTask.isCompleted,
                    Schema.Tasks.isDeleted <- newTask.isDeleted
                )
            )
            
            return newTask
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return nil
        }
    }
    
    func update<T>(task: KillerTask, suchThat path: KeyPath<KillerTask, T>, is value: T) where T: SQLite.Value {
        do {
            try connection.run(
                Schema.Tasks.tableExpression
                    .filter(Schema.Tasks.id == task.id)
                    .update(Schema.Tasks.from(keyPath: path) <- value)
            )
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
        }
    }
    
    private func newId() -> Int {
        do {
            let max: Int? = try connectionManager.activeConnection!.scalar(
                Schema.Tasks.tableExpression.select(Schema.Tasks.id.max)
            )
            return max?.advanced(by: 1) ?? 1
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return 1
        }
    }
}

extension EnvironmentValues {
    @Entry var database: Database? = nil
}

extension Database {
    class ConnectionManager {
        private let databaseName: String
        var activeConnection : SQLite.Connection? = nil
        
        init(databaseName: String) {
            self.databaseName = databaseName
        }
        
        func createConnection() throws(DatabaseConnectionError) {
            guard activeConnection == nil else {
                return
            }
            
            guard let userDocumentsDir else {
                throw DatabaseConnectionError.couldNotAccessDocumentsDirectory
            }
            
            do {
                self.activeConnection = try Connection("\(userDocumentsDir)/\(databaseName).sqlite3")
            }
            catch {
                throw DatabaseConnectionError.couldNotCreateConnection(because: error)
            }
        }
        
        private var userDocumentsDir: String? {
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        }
    }
}

extension Database {
    enum SchemaDescription {
        case userData
        
        var fileName: String {
            switch self {
            case .userData: "user_data"
            }
        }
        
        func create(connection: SQLite.Connection) throws {
            switch self {
            case .userData:
                try connection.run(Schema.Tasks.create)
            }
        }
        
        func destroy(connection: SQLite.Connection) throws {
            switch self {
            case .userData:
                try connection.run(Schema.Tasks.drop)
            }
        }
    }
}

extension Database {
    enum Schema {
        enum Tasks {
            static let tableExpression: SQLite.Table = Table("tasks")
            
            static let id = SQLite.Expression<Int>("id")
            static let body = SQLite.Expression<String>("body")
            static let isCompleted = SQLite.Expression<Bool>("isCompleted")
            static let isDeleted = SQLite.Expression<Bool>("isDeleted")
            
            static func from<T>(keyPath: KeyPath<KillerTask, T>) throws -> SQLite.Expression<T> where T: SQLite.Value {
                switch keyPath {
                case \.id: id as! SQLite.Expression<T>
                case \.body: body as! SQLite.Expression<T>
                case \.isCompleted: isCompleted as! SQLite.Expression<T>
                case \.isDeleted: isDeleted as! SQLite.Expression<T>
                default: fatalError()
                }
            }
            
            static var create: String {
                self.tableExpression.create(ifNotExists: true) {
                    $0.column(Schema.Tasks.id, primaryKey: .autoincrement)
                    $0.column(Schema.Tasks.body)
                    $0.column(Schema.Tasks.isCompleted)
                    $0.column(Schema.Tasks.isDeleted)
                }
            }
            
            static var drop: String {
                self.tableExpression.drop()
            }
        }
    }
}
