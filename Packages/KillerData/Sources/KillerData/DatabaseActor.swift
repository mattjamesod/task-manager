import SQLite
import SwiftUI
import UtilExtensions

enum DatabaseConnectionError: Error {
    case couldNotAccessDocumentsDirectory
    case couldNotCreateConnection(because: Error)
}

public enum DatabaseError: Error {
    case couldNotEstablishConnection
    case couldNotCreateSchema
    case propertyDoesNotExist
}

/// Actor to perform methods on a given SQLite Database, from a list of pre-defined database structures
/// Methods catch lower-level errors and log to analytiocs, then throw higher-level errors
public actor Database {
    private let schema: SchemaDescription
    private let connection: Connection
    
    internal init(schema: Database.SchemaDescription, connection: SQLite.Connection) throws(DatabaseError) {
        self.schema = schema
        self.connection = connection
        
        do {
//            try schema.destroy(connection: connection)
            try schema.create(connection: connection)
        }
        catch {
            throw DatabaseError.couldNotCreateSchema
        }
    }
    
    internal static func inMemory() -> Database {
        try! Database(schema: .testing, connection: Connection())
    }
    
    public func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, id: Int, context: Database.Query? = nil) -> ModelType? {
        do {
            let query = context?.tableExpression ?? ModelType.SchemaType.tableExpression
            let record = try connection.pluck(query.filter(Schema.Tasks.id == id))
            
            guard let record else { return nil }
            
            return try ModelType.create(from: record)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return nil
        }
    }
    
    public func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, query: Database.Query) -> [ModelType] {
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
    
    public func count<ModelType: SchemaBacked>(_ type: ModelType.Type, query: Database.Query) -> Int {
        do {
            return try connection.scalar(query.tableExpression.count)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            return 0
        }
    }
    
    @discardableResult
    public func insert<ModelType: SchemaBacked, PropertyType1: SQLite.Value>(
        _ type: ModelType.Type,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) -> ModelType? {
        self.insert(type, {[
            try property1.getSetter()
        ]})
    }
    
    @discardableResult
    public func insert<ModelType: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ type: ModelType.Type,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) -> ModelType? {
        self.insert(type, {[
            try property1.getSetter(),
            try property2.getSetter()
        ]})
    }
    
    private func insert<ModelType: SchemaBacked>(_ typ: ModelType.Type, _ setters: () throws -> [Setter]) -> ModelType? {
        do {
            let newId = try connection.run(
                ModelType.SchemaType.tableExpression.insert(setters())
            )
                        
            let result = try connection.prepare(
                ModelType.SchemaType.tableExpression
                    .filter(Schema.Tasks.id == Int(newId))
            )
            .map(ModelType.create(from:))
            .first
            
            Task.detached {
                await ModelType.messageHandler.send(.recordChange(id: Int(newId)))
            }
            
            return result
        }
        catch {
            // sqlite specific errors, print problem query?
            // do something to broad cast the error to both you and the user
            print(error)
            return nil
        }
    }
    
    // parameter packs and concurrency do NOT play nicely, therefor just add helpers
    // for however many args needed...
    public func update<ModelType: SchemaBacked, PropertyType1: SQLite.Value>(
        _ model: ModelType,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) {
        self.update(model, {[
            try property1.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ]})
    }
    
    public func update<ModelType: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ model: ModelType,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) {
        self.update(model, {[
            try property1.getSetter(),
            try property2.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ]})
    }
    
    // TODO:  If the model has no matching record in the database, it is created with the updated value.
    private func update<ModelType: SchemaBacked>(_ model: ModelType, _ setters: () throws -> [Setter]) {
        do {
            guard let id = model.id else { return }
            
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.id == id)
                    .update(setters())
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordChange(id: id))
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
        
    public func purgeRecentlyDeleted<ModelType: SchemaBacked>(_ type: ModelType.Type) {
        do {
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.deletedAt < 30.days.ago)
                    .delete()
            )
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
}

public extension EnvironmentValues {
    @Entry var database: Database? = nil
}
