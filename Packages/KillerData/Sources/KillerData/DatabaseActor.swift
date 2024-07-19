import SQLite
import SwiftUI
import UtilExtensions
import KillerModels

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
    
    public func pluck<ModelType: SchemaBacked>(_ type: ModelType.Type, id: Int, context: Database.Query? = nil) -> ModelType? {
        do {
            let query = context?.apply(ModelType.SchemaType.tableExpression) ?? ModelType.SchemaType.tableExpression
            let record = try connection.pluck(query.filter(Schema.Tasks.id == id))
            
            guard let record else { return nil }
            
            return try ModelType.create(from: record)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return nil
        }
    }
    
    public func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, query: Database.Query) -> [ModelType] {
        do {
            let records = try connection.prepare(query.apply(ModelType.SchemaType.tableExpression))
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func fetch<ModelType: SchemaBacked & RecursiveData>(_ type: ModelType.Type, rootID: Int, context: Database.Query? = nil) -> [ModelType] {
        do {
            let table = context?.apply(ModelType.SchemaType.tableExpression) ?? ModelType.SchemaType.tableExpression
            
            let recursiveExpression = buildRecursiveExpression(ModelType.self, rootID: rootID, base: table)
            
            let records = try connection.prepare(recursiveExpression)
            
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func count<ModelType: SchemaBacked>(_ type: ModelType.Type, query: Database.Query) -> Int {
        do {
            return try connection.scalar(query.apply(ModelType.SchemaType.tableExpression).count)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return 0
        }
    }
    
    public func insert<ModelType: SchemaBacked, PropertyType1: SQLite.Value>(
        _ type: ModelType.Type,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) {
        self.insert(type, {[
            try property1.getSetter(),
            ModelType.SchemaType.createdAt <- Date.now,
            ModelType.SchemaType.updatedAt <- Date.now
        ]})
    }
    
    public func insert<ModelType: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ type: ModelType.Type,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) {
        self.insert(type, {[
            try property1.getSetter(),
            try property2.getSetter(),
            ModelType.SchemaType.createdAt <- Date.now,
            ModelType.SchemaType.updatedAt <- Date.now
        ]})
    }
    
    private func insert<ModelType: SchemaBacked>(_ type: ModelType.Type, _ setters: () throws -> [Setter]) {
        do {
            let newId = try connection.run(
                ModelType.SchemaType.tableExpression.insert(setters())
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordChange(id: Int(newId)))
            }
        }
        catch {
            // sqlite specific errors, print problem query?
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    // parameter packs and concurrency do NOT play nicely, therefor just add helpers
    // for however many args needed...
    public func update<ModelType: SchemaBacked, PropertyType1: SQLite.Value>(
        _ model: ModelType,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) {
        let setters = [
            try? property1.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        self.update(model, setters)
    }
    
    public func update<ModelType: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ model: ModelType,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) {
        let setters = [
            try? property1.getSetter(),
            try? property2.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        self.update(model, setters)
    }
    
    public func update<ModelType: SchemaBacked & RecursiveData, PropertyType1: SQLite.Value>(
        _ model: ModelType,
        recursive: Bool = false,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) {
        let updateMethod: (ModelType, [Setter]) -> () =
            recursive ? self.updateRecursive : self.update
        
        let setters = [
            try? property1.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        updateMethod(model, setters)
    }
    
    public func update<ModelType: SchemaBacked & RecursiveData, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ model: ModelType,
        recursive: Bool = false,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) {
        let updateMethod: (ModelType, [Setter]) -> () = 
            recursive ? self.updateRecursive : self.update
        
        let setters = [
            try? property1.getSetter(),
            try? property2.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        updateMethod(model, setters)
    }
    
    // TODO:  If the model has no matching record in the database, it is created with the updated value.
    private func update<ModelType: SchemaBacked>(_ model: ModelType, _ setters: [Setter]) {
        do {
            guard let id = model.id else { return }
            
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.id == id)
                    .update(setters)
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordChange(id: id))
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func updateRecursive<ModelType: SchemaBacked & RecursiveData>(_ model: ModelType, _ setters: [Setter]) {
        do {
            guard let id = model.id else { return }
            
            let affectedIDs = try connection
                .prepare(buildRecursiveExpression(ModelType.self, rootID: id, base: ModelType.SchemaType.tableExpression))
                .map { $0[ModelType.SchemaType.id] }
            
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .where(affectedIDs.contains(ModelType.SchemaType.id))
                    .update(setters)
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordsChanged(ids: Set(affectedIDs)))
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
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
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func buildRecursiveExpression<ModelType: SchemaBacked & RecursiveData>(_ type: ModelType.Type, rootID: Int, base: SQLite.Table) -> SQLite.Table {
        let cte = Table("cte")
                    
        let compoundQuery = base
            .where(SQLite.Expression<Int>("id") == rootID)
            .union(
                cte.join(base, on: cte[SQLite.Expression<Int>("id")] == base[SQLite.Expression<Int>("parentID")])
                   .select(base[*])
            )
        
        return cte.with(cte, recursive: true, as: compoundQuery)
    }
}

public extension EnvironmentValues {
    @Entry var database: Database? = nil
}
