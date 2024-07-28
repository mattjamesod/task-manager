@preconcurrency import SQLite
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
    private let history: MutationHistory = .init()
    
    public func undo() async { await history.undo() }
    public func redo() async { await history.redo() }
    
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
    
    public func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, context: Database.Query?) -> [ModelType] {
        do {
            let table = ModelType.SchemaType.tableExpression
            let query = context?.apply(table) ?? table
            let records = try connection.prepare(query)
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func pluck<ModelType: SchemaBacked>(_ type: ModelType.Type, id: Int, context: Database.Query? = nil) -> ModelType? {
        do {
            let table = ModelType.SchemaType.tableExpression
            let query = context?.apply(table) ?? table
            let record = try connection.pluck(query.filter(table[ModelType.SchemaType.id] == id))
            
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
    
    public func fetch<ModelType: SchemaBacked>(_ type: ModelType.Type, ids: Set<Int>, context: Database.Query? = nil) -> [ModelType] {
        do {
            let table = ModelType.SchemaType.tableExpression
            let query = context?.apply(table) ?? table
            let records = try connection.prepare(query.filter(ids.contains(table[ModelType.SchemaType.id])))
            
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func fetchRecursive<ModelType: SchemaBacked & RecursiveData>(_ type: ModelType.Type, ids: Set<Int>, context: Database.Query? = nil) -> [ModelType] {
        do {
            let table = ModelType.SchemaType.tableExpression
            let query = context?.apply(table) ?? table
            
            let records = try connection
                .prepare(buildRecursiveExpression(
                    ModelType.self,
                    ids: ids,
                    base: query
                ))
            
            return try records.map(ModelType.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func fetchChildren<ModelType: SchemaBacked>(
        _ type: ModelType.Type, id: Int?,
        context: Database.Query? = nil
    ) -> [ModelType] where ModelType : RecursiveData {
        do {
            let table = ModelType.SchemaType.tableExpression
            let query = context?.apply(table) ?? table
            let records = try connection.prepare(query.filter(SQLite.Expression<Int?>("parentID") == id))
            
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
    ) async {
        var setters = [
            try? property1.getSetter(),
            ModelType.SchemaType.createdAt <- Date.now,
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        guard let id = self.insert(type, setters) else { return }
        
        setters.append(ModelType.SchemaType.id <- id)
        
        let finalSetters = setters
        
        await history.record(Bijection(
            goForward: { await self.insert(type, finalSetters) },
            goBackward: { await self.delete(ModelType.self, id) }
        ))
    }
    
    public func insert<ModelType: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ type: ModelType.Type,
        _ property1: PropertyArgument<ModelType, PropertyType1>,
        _ property2: PropertyArgument<ModelType, PropertyType2>
    ) async {
        var setters = [
            try? property1.getSetter(),
            try? property2.getSetter(),
            ModelType.SchemaType.createdAt <- Date.now,
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        guard let id = self.insert(type, setters) else { return }
        
        setters.append(ModelType.SchemaType.id <- id)
        
        let finalSetters = setters
        
        await history.record(Bijection(
            goForward: { await self.insert(type, finalSetters) },
            goBackward: { await self.delete(ModelType.self, id) }
        ))
    }
    
    @discardableResult
    private func insert<ModelType: SchemaBacked>(_ type: ModelType.Type, _ setters: [Setter]) -> Int? {
        do {
            let newId = try connection.run(
                ModelType.SchemaType.tableExpression.insert(setters)
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordChange(id: Int(newId)))
            }
            
            return Int(newId)
        }
        catch {
            // sqlite specific errors, print problem query?
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
            return nil
        }
    }
    
    // parameter packs and concurrency do NOT play nicely, therefor just add helpers
    // for however many args needed...
    public func update<ModelType: SchemaBacked, PropertyType1: SQLite.Value>(
        _ model: ModelType,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) async {
        let forwardSetters = [
            try? property1.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        let backwardSetters = [
            try? property1.getInverseSetter(model: model),
            ModelType.SchemaType.updatedAt <- model.updatedAt
        ].compact()
        
        await history.record(Bijection(
            goForward: { await self.update(model, forwardSetters) },
            goBackward: { await self.update(model, backwardSetters) }
        ))
        
        self.update(model, forwardSetters)
    }
    
    public func update<ModelType: SchemaBacked & RecursiveData, PropertyType1: SQLite.Value>(
        _ model: ModelType,
        recursive: Bool = false,
        context query: Query? = nil,
        _ property1: PropertyArgument<ModelType, PropertyType1>
    ) async {
        guard let id = model.id else { return }
        
        let ids: [Int]
        
        if recursive {
            do {
                ids = try connection
                    .prepare(buildRecursiveExpression(
                        ModelType.self,
                        name: "updateCTE",
                        rootID: id,
                        base: query?.apply(ModelType.SchemaType.tableExpression) ?? ModelType.SchemaType.tableExpression
                    ))
                    .map { $0[ModelType.SchemaType.id] }
            }
            catch {
                // do something to broad cast the error to both you and the user
                print(error)
                print("\(#file):\(#function):\(#line)")
                return
            }
        }
        else {
            ids = [id]
        }
        
        let forwardSetters = [
            try? property1.getSetter(),
            ModelType.SchemaType.updatedAt <- Date.now
        ].compact()
        
        let backwardSetters = [
            try? property1.getInverseSetter(model: model),
            ModelType.SchemaType.updatedAt <- model.updatedAt
        ].compact()
        
        await history.record(Bijection(
            goForward: { await self.update(ModelType.self, ids: ids, forwardSetters) },
            goBackward: { await self.update(ModelType.self, ids: ids, backwardSetters) }
        ))
        
        self.update(ModelType.self, ids: ids, forwardSetters)
    }
    
    // TODO:  If the model has no matching record in the database, it is created with the updated value.
    private func update<ModelType: SchemaBacked>(_ model: ModelType, _ setters: [Setter]) {
        do {
            guard let id = model.id else { return }
            update(ModelType.self, ids: [id], setters)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func update<ModelType: SchemaBacked>(
        _ type: ModelType.Type,
        ids: [Int],
        _ setters: [Setter]
    ) {
        do {
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .where(ids.contains(ModelType.SchemaType.id))
                    .update(setters)
            )
            
            if ids.count == 1 {
                Task.detached {
                    await ModelType.messageHandler.send(.recordChange(id: ids.first!))
                }
            }
            else {
                Task.detached {
                    await ModelType.messageHandler.send(.recordsChanged(ids: Set(ids)))
                }
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func delete<ModelType: SchemaBacked>(_ type: ModelType.Type, _ id: Int) {
        do {
            try connection.run(
                ModelType.SchemaType.tableExpression
                    .filter(ModelType.SchemaType.id == id)
                    .delete()
            )
            
            Task.detached {
                await ModelType.messageHandler.send(.recordDeleted(id: id))
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
    
    private func buildRecursiveExpression<ModelType: SchemaBacked & RecursiveData>(_ type: ModelType.Type, name: String, rootID: Int?, base: SQLite.Table) -> SQLite.Table {
        let cte = Table(name)
                    
        let compoundQuery = base
            .where(base[SQLite.Expression<Int?>("id")] == rootID)
            .union(
                cte.join(base, on: cte[SQLite.Expression<Int>("id")] == base[SQLite.Expression<Int>("parentID")])
                   .select(base[*])
            )
        
        return cte.with(cte, recursive: true, as: compoundQuery)
    }
    
    private func buildRecursiveExpression<ModelType: SchemaBacked & RecursiveData>(_ type: ModelType.Type, ids: Set<Int>, base: SQLite.Table) -> SQLite.Table {
        let cte = Table("cte")
                    
        let compoundQuery = base
            .where(ids.contains(base[SQLite.Expression<Int?>("id")]))
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
