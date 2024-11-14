import Foundation
import SQLite

public class DatabaseSetupHelper {
    private let schema: Database.SchemaDescription
    
    public init(schema: Database.SchemaDescription) {
        self.schema = schema
    }
    
    public func setup() throws(DatabaseError) -> Database {
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
        
        let db = try Database(schema: schema, connection: connection)
        
        Task {
            await db.enableCloudKit(containerID: "")
        }
        
        return db
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
