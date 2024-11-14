import Foundation
import SQLite
import KillerModels

public class DatabaseSetupHelper {
    private let schema: Database.SchemaDescription
    
    public init(schema: Database.SchemaDescription) {
        self.schema = schema
    }
    
    public func setupDatabase() throws(DatabaseError) -> Database {
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

extension Database {
    public nonisolated func enableCloudkitSync() -> Database.CloudKitMonitor {
        let cloudKitMonitor = Database.CloudKitMonitor(database: self)
        
        Task { await cloudKitMonitor.waitForChanges() }
        
        return cloudKitMonitor
    }
}

extension Database {
    public enum SchemaDescription: Sendable {
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
        
        func subscribeToAll() async -> [AsyncMessageHandler<DatabaseMessage>.Thread] {
            switch self {
            case .userData: [ await KillerTask.messageHandler.subscribe() ]
            case .testing: [ await KillerTask.messageHandler.subscribe() ]
            }
        }
    }
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
