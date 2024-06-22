import SwiftUI
import SQLite

actor Database {
    private let connectionManager: ConnectionManager
    
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
        var records: AnySequence<SQLite.Row> = .init([])
        
        do {
            records = try connectionManager.activeConnection!.prepare(Schema.Tasks.tableExpression)
        }
        catch {
            // log error somewhere in analytics, display generic message to user
        }
        
        return makeTasks(
            from: records
        )
    }
    
    func newTask() -> KillerTask {
        let newTask = KillerTask(id: newId(), body: "I am a brand new baby task")
        
        do {
            try connectionManager.activeConnection!.run(
                Schema.Tasks.tableExpression.insert(
                    Schema.id <- newTask.id,
                    Schema.Tasks.body <- newTask.body,
                    Schema.Tasks.isCompleted <- newTask.isCompleted,
                    Schema.isDeleted <- newTask.isDeleted
                )
            )
        }
        catch {
            // log error somewhere in analytics, display generic message to user
        }
        
        return newTask
    }
    
    func update<T>(task: KillerTask, suchThat path: WritableKeyPath<KillerTask, T>, is value: T) {
//        do {
//            try connectionManager.activeConnection!.run(
//                Schema.Tasks.tableExpression.update(
//                    Schema.id <- newTask.id,
//                    Schema.Tasks.body <- newTask.body,
//                    Schema.Tasks.isCompleted <- newTask.isCompleted,
//                    Schema.isDeleted <- newTask.isDeleted
//                )
//            )
//        }
//        catch {
//            // log error somewhere in analytics, display generic message to user
//        }
    }
    
    private func newId() -> Int {
        do {
            let max: Int? = try connectionManager.activeConnection!.scalar(
                Schema.Tasks.tableExpression.select(Schema.id.max)
            )
            return max?.advanced(by: 1) ?? 1
        }
        catch {
            // log error somewhere in analytics, display generic message to user
            
            return 1
        }
    }
    
    private var taskDatabase: [KillerTask] = [
        KillerTask(id: 1, body: "Take out the trash"),
        KillerTask(id: 2, body: "Buy milk"),
        KillerTask(id: 3, body: "Work on important project")
    ]
    
    private func makeTasks(from rows: AnySequence<SQLite.Row>) -> [KillerTask] {
        rows.map {
            KillerTask(
                id: $0[Schema.id],
                body: $0[Schema.Tasks.body],
                isCompleted: $0[Schema.Tasks.isCompleted],
                isDeleted: $0[Schema.isDeleted]
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
        static let id = SQLite.Expression<Int>("id")
        static let isDeleted = SQLite.Expression<Bool>("isDeleted")
        
        enum Tasks {
            static let tableExpression: SQLite.Table = Table("tasks")
            static let body = SQLite.Expression<String>("body")
            static let isCompleted = SQLite.Expression<Bool>("isCompleted")
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
                    $0.column(Schema.id, primaryKey: .autoincrement)
                    $0.column(Schema.Tasks.body)
                    $0.column(Schema.Tasks.isCompleted)
                    $0.column(Schema.isDeleted)
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
