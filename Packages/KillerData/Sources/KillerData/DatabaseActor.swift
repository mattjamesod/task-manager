import SQLite
import SwiftUI

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
            try schema.create(connection: connection)
        }
        catch {
            throw DatabaseError.couldNotCreateSchema
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
    
    @discardableResult
    public func insert<ModelType: SchemaBacked, each T: SQLite.Value>(
        _ type: ModelType.Type,
        _ properties: repeat PropertyArgument<ModelType, each T>
    ) -> ModelType? {
        do {
            // no way to map over a parameter pack since you have to `repeat` them, so here
            // we use a slightly ugly loop to generate an array of property setters
            
            var setters: [Setter] = []
            
            for property in repeat each properties {
                setters.append(try property.getSetter())
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
    public func update<ModelType: SchemaBacked, PropertyType: SQLite.Value>(
        _ model: ModelType,
        suchThat path: KeyPath<ModelType, PropertyType?>,
        is value: PropertyType?)
    {
        do {
            try update(model, setter: ModelType.getSchemaExpression(optional: path) <- value)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
    
    public func update<ModelType: SchemaBacked, PropertyType: SQLite.Value>(
        _ model: ModelType,
        suchThat path: KeyPath<ModelType, PropertyType>,
        is value: PropertyType)
    {
        do {
            try update(model, setter: ModelType.getSchemaExpression(for: path) <- value)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
    
    private func update<ModelType: SchemaBacked>(_ model: ModelType, setter: Setter) throws {
        guard let id = model.id else { return }
        
        try connection.run(
            ModelType.SchemaType.tableExpression
                .filter(ModelType.SchemaType.id == id)
                .update(setter, Schema.Tasks.updatedAt <- Date.now)
        )
    }
        
    public func purgeRecentlyDeleted<ModelType: SchemaBacked>(_ model: ModelType) {
        do {
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.deletedAt < Calendar.current.date(byAdding: DateComponents(day: -1), to: Date.now)!)
                    .delete()
            )
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
        }
    }
}

extension Database {
    public enum Query {
        case allActiveItems
        
        var tableExpression: SQLite.Table{
            switch self {
            case .allActiveItems: Schema.Tasks.tableExpression.filter(
                Schema.Tasks.completedAt == nil && Schema.Tasks.deletedAt == nil
            )
            }
        }
    }
}

public extension EnvironmentValues {
    @Entry public var database: Database? = nil
}
