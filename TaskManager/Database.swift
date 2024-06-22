import SwiftUI
import SQLite

actor DesiredDB {
}

actor Database {
    private let connectionManager: ConnectionManager
    private var connection: Connection { connectionManager.activeConnection! }
    
    init(name: String) {
        self.connectionManager = ConnectionManager(databaseName: name)
        
        do {
            try self.connectionManager.createConnection()
            try SchemaManager(connectionManager: self.connectionManager).create()
        }
        catch {
            fatalError("""
                Unrecoverable Database Error! Could not connect to the database. \
                Details: \(error).
            """)
        }
    }
    
    func fetchTasks() -> [KillerTask] {
        do {
            let records = try connection.prepare(
                Schema.Tasks.tableExpression
                    .filter(!Schema.Tasks.isCompleted)
                    .filter(!Schema.Tasks.isDeleted)
            )
            
            return makeTasks(from: records)
        }
        catch {
            print(error.localizedDescription)
            fatalError("""
                Unrecoverable Database Error! Could not fetch from database. \
                Details: \(error).
            """)
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
            print(error.localizedDescription)
            fatalError("""
                Unrecoverable Database Error! Could not write to database. \
                Details: \(error).
            """)
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
            print(error.localizedDescription)
            fatalError("""
                Unrecoverable Database Error! Could not write to database. \
                Details: \(error).
            """)
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
            print(error.localizedDescription)
            fatalError("""
                Unrecoverable Database Error! Could not read from database. \
                Details: \(error).
            """)
        }
    }
    
    private func makeTasks(from rows: AnySequence<SQLite.Row>) -> [KillerTask] {
        rows.map {
            KillerTask(
                id: $0[Schema.Tasks.id],
                body: $0[Schema.Tasks.body],
                isCompleted: $0[Schema.Tasks.isCompleted],
                isDeleted: $0[Schema.Tasks.isDeleted]
            )
        }
    }
}

extension EnvironmentValues {
    @Entry var database: Database? = nil
}

extension Database {
    class ConnectionManager {
        enum DatabaseConnectionError: Error {
            case couldNotAccessDocumentsDirectory
        }
        
        private let databaseName: String
        var activeConnection : SQLite.Connection? = nil
        
        init(databaseName: String) {
            self.databaseName = databaseName
        }
        
        func createConnection() throws {
            guard activeConnection == nil else {
                return
            }
            
            guard let userDocumentsDir else {
                throw DatabaseConnectionError.couldNotAccessDocumentsDirectory
            }
            
            self.activeConnection = try Connection("\(userDocumentsDir)/\(databaseName).sqlite3")
        }
        
        private var userDocumentsDir: String? {
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
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
        }
    }
    
    class SchemaManager {
        private let connectionManager: ConnectionManager
        
        init(connectionManager: ConnectionManager) {
            self.connectionManager = connectionManager
        }
        
        func create() throws {
            try connectionManager.activeConnection!.run(
                Schema.Tasks.tableExpression.create(ifNotExists: true) {
                    $0.column(Schema.Tasks.id, primaryKey: .autoincrement)
                    $0.column(Schema.Tasks.body)
                    $0.column(Schema.Tasks.isCompleted)
                    $0.column(Schema.Tasks.isDeleted)
                }
            )
        }
        
        func destroy() throws {
            try connectionManager.activeConnection!.run(
                Schema.Tasks.tableExpression.drop()
            )
        }
    }
}
