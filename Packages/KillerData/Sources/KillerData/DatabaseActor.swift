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

public enum DatabaseMessage: Sendable {
    public enum Sender: Sendable {
        case userInterface
        case cloudSync
    }
    
    case recordChange(_ type: any SchemaBacked.Type, id: UUID, sender: Sender = .userInterface)
    case recordsChanged(_ type: any SchemaBacked.Type, ids: Set<UUID>, sender: Sender = .userInterface)
    case recordDeleted(_ type: any SchemaBacked.Type, id: UUID, sender: Sender = .userInterface)
    case recordsDeleted(_ type: any SchemaBacked.Type, ids: Set<UUID>, sender: Sender = .userInterface)
    
    var type: any SchemaBacked.Type {
        switch self {
        case .recordChange(let type, let _, let _): type
        case .recordsChanged(let type, let _, let _): type
        case .recordDeleted(let type, let _, let _): type
        case .recordsDeleted(let type, let _, let _): type
        }
    }
    
    var sender: Sender {
        switch self {
        case .recordChange(let _, let _, let sender): sender
        case .recordsChanged(let _, let _, let sender): sender
        case .recordDeleted(let _, let _, let sender): sender
        case .recordsDeleted(let _, let _, let sender): sender
        }
    }
}

/// Actor to perform methods on a given SQLite Database, from a list of pre-defined database structures
/// Methods catch lower-level errors and log to analytiocs, then throw higher-level errors
public actor Database {
    let schema: SchemaDescription
    private let connection: Connection
    
    nonisolated public let registry: ModelRegistry = .init()
    
    private let history: MutationHistory = .init()
    
    public func undo() async { await history.undo() }
    public func redo() async { await history.redo() }
    
    private let events: AsyncMessageHandler<DatabaseMessage>
    
    public func subscribe() async -> AsyncMessageHandler<DatabaseMessage>.Thread {
        await self.events.subscribe()
    }
    
    public func subscribe(to sender: DatabaseMessage.Sender) async -> AsyncMessageHandler<DatabaseMessage>.Thread {
        await self.events.subscribe(predicate: { event in
            event.sender == sender
        })
    }
    
    public func subscribe<Model: SchemaBacked>(
        to modelType: Model.Type
    ) async -> AsyncMessageHandler<DatabaseMessage>.Thread {
        return await self.events.subscribe(predicate: { event in
            event.type is Model.Type
        })
    }
    
    public func unsubscribe(_ thread: AsyncMessageHandler<DatabaseMessage>.Thread) async {
        await self.events.unsubscribe(thread)
    }
    
    public func send(_ message: DatabaseMessage) async {
        await self.events.send(message)
    }
    
    internal init(schema: Database.SchemaDescription, connection: SQLite.Connection) throws(DatabaseError) {
        self.schema = schema
        self.connection = connection
        self.events = .init()
        
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
    
    public func fetch<Model: SchemaBacked>(_ type: Model.Type, context: Database.Scope<Model>?) -> [Model] {
        do {
            let table = Model.Schema.baseExpression
            let query = context?.apply(table) ?? table
//            print(query.expression)
//            print("--------------")
            let records = try connection.prepare(query)
            return try records.map(Model.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func pluck<Model: SchemaBacked>(_ type: Model.Type, id: UUID, context: Database.Scope<Model>? = nil) -> Model? {
        do {
            let table = Model.Schema.baseExpression
            let query = context?.apply(table) ?? table
            let record = try connection.pluck(query.filter(table[Model.Schema.id] == id))
            
//            print(query.filter(table[Model.Schema.id] == id).expression)
//            print("--------------")
            
            guard let record else { return nil }
            
            return try Model.create(from: record)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return nil
        }
    }
    
    public func fetch<Model: SchemaBacked>(_ type: Model.Type, ids: Set<UUID>, context: Database.Scope<Model>? = nil) -> [Model] {
        do {
            let table = Model.Schema.baseExpression
            let query = context?.apply(table) ?? table
            let records = try connection.prepare(query.filter(ids.contains(table[Model.Schema.id])))
            
//            print(query.filter(ids.contains(table[Model.Schema.id])).expression)
//            print("--------------")
            
            return try records.map(Model.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func fetchRecursive<Model: SchemaBacked & RecursiveData>(_ type: Model.Type, ids: Set<UUID>, context: Database.Scope<Model>? = nil) -> [Model] {
        do {
            let table = Model.Schema.baseExpression
            let query = context?.apply(table) ?? table
            
            let records = try connection
                .prepare(buildRecursiveExpression(
                    Model.self,
                    ids: ids,
                    base: query
                ))
            
            return try records.map(Model.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func fetchChildren<Model: SchemaBacked>(
        _ type: Model.Type, id: UUID?,
        context: Database.Scope<Model>? = nil
    ) -> [Model] where Model : RecursiveData {
        do {
            let table = Model.Schema.baseExpression
            let query = context?.apply(table) ?? table
            let records = try connection.prepare(query.filter(SQLite.Expression<UUID?>("parentID") == id))
            
            return try records.map(Model.create(from:))
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return []
        }
    }
    
    public func count<Model: SchemaBacked>(_ type: Model.Type, query: Database.Scope<Model>) -> Int {
        do {
            return try connection.scalar(query.apply(Model.Schema.baseExpression).count)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error.localizedDescription)
            print("\(#file):\(#function):\(#line)")
            return 0
        }
    }
    
    public func insert<Model: SchemaBacked, PropertyType1: SQLite.Value>(
        _ type: Model.Type,
        _ property1: PropertyArgument<Model, PropertyType1>,
        context: Database.Scope<Model>? = nil
    ) async {
        let id = UUID()
        let creation = Model.creationProperties()
        let context = context?.insertProperties ?? []
        let manuallyRequested = [ try? property1.getSetter() ].compact()
        
        var setters = creation + context + manuallyRequested
        
        guard self.insert(type, id, setters) else { return }
                
        let finalSetters = setters
        
        await history.record(Bijection(
            goForward: { await self.insert(type, id, finalSetters) },
            goBackward: { await self.delete(type, id) }
        ))
    }
    
    public func insert<Model: SchemaBacked, PropertyType1: SQLite.Value, PropertyType2: SQLite.Value>(
        _ type: Model.Type,
        _ property1: PropertyArgument<Model, PropertyType1>,
        _ property2: PropertyArgument<Model, PropertyType2>,
        context: Database.Scope<Model>? = nil
    ) async {
        let id = UUID()
        let creation = Model.creationProperties()
        let context = context?.insertProperties ?? []
        
        let manuallyRequested = [
            try? property1.getSetter(),
            try? property2.getSetter()
        ].compact()
        
        var setters = creation + context + manuallyRequested
        
        guard self.insert(type, id, setters) else { return }
        
        let finalSetters = setters
        
        await history.record(Bijection(
            goForward: { await self.insert(type, id, finalSetters) },
            goBackward: { await self.delete(type, id) }
        ))
    }
    
    public func duplicate<Model: SchemaBacked>(_ model: Model) async {
        let id = UUID()
        var setters = model.duplicationProperties()
        
        setters.append(contentsOf: [
            Model.Schema.id <- id,
            Model.Schema.createdAt <- Date.now,
            Model.Schema.updatedAt <- Date.now
        ])
        
        guard self.insert(Model.self, id, setters) else { return }
        
        let finalSetters = setters
        
        await history.record(Bijection(
            goForward: { await self.insert(Model.self, id, finalSetters) },
            goBackward: { await self.delete(Model.self, id) }
        ))
    }
    
    // what is now the purpose of this method? should it expose errors
    @discardableResult
    internal func insert<Model: SchemaBacked>(
        _ type: Model.Type,
        _ id: UUID,
        _ setters: [Setter],
        sender: DatabaseMessage.Sender = .userInterface
    ) -> Bool {
        do {
            let finalSetters = setters + [Model.Schema.id <- id]
            
            try connection.run(
                Model.Schema.baseExpression.insert(finalSetters)
            )
            
            Task.detached {
                await self.send(.recordChange(type, id: id, sender: sender))
            }
            
            return true
        }
        catch {
            // sqlite specific errors, print problem query?
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
            return false
        }
    }
    
    public func upsert<Model: SchemaBacked, PropertyType1: SQLite.Value>(
        _ model: Model,
        _ property1: PropertyArgument<Model, PropertyType1>
    ) async {
        let persisted = model.createdAt != nil
        let existingProperties = model.allProperties()
        let manuallyRequested = [
            try? property1.getSetter(),
            !persisted ? Model.Schema.createdAt <- Date.now : nil,
            Model.Schema.updatedAt <- Date.now
        ].compact()
        
        // manually requested must come first, as there are duplicates
        var setters = manuallyRequested + existingProperties
        
        guard self.upsert(Model.self, model.id, setters) else { return }
                
        let finalSetters = setters
        let inverseSetters = [
            try? property1.getInverseSetter(model: model),
            Model.Schema.updatedAt <- model.updatedAt
        ].compact()
        
        await history.record(Bijection(
            goForward: { await self.upsert(Model.self, model.id, finalSetters) },
            goBackward: {
                if persisted {
                    await self.update(model, inverseSetters)
                }
                else {
                    await self.delete(Model.self, model.id)
                }
                
            }
        ))
    }
    
    @discardableResult
    internal func upsert<Model: SchemaBacked>(
        _ type: Model.Type,
        _ id: UUID,
        _ setters: [Setter]
    ) -> Bool {
        do {
            let finalSetters = setters + [Model.Schema.id <- id]
            
                        
            try connection.run(
                Model.Schema.baseExpression.upsert(finalSetters, onConflictOf: Model.Schema.id)
            )
            
            Task.detached {
                await self.send(.recordChange(type, id: id))
            }
            
            return true
        }
        catch {
            // sqlite specific errors, print problem query?
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
            return false
        }
    }
    
    // parameter packs and concurrency do NOT play nicely, therefor just add helpers
    // for however many args needed...
    public func update<Model: SchemaBacked, PropertyType1: SQLite.Value>(
        _ model: Model,
        _ property1: PropertyArgument<Model, PropertyType1>
    ) async {
        let forwardSetters = [
            try? property1.getSetter(),
            Model.Schema.updatedAt <- Date.now
        ].compact()
        
        let backwardSetters = [
            try? property1.getInverseSetter(model: model),
            Model.Schema.updatedAt <- model.updatedAt
        ].compact()
        
        await history.record(Bijection(
            goForward: { await self.update(model, forwardSetters) },
            goBackward: { await self.update(model, backwardSetters) }
        ))
        
        self.update(model, forwardSetters)
    }
    
    public func update<Model: SchemaBacked & RecursiveData, PropertyType1: SQLite.Value>(
        _ model: Model,
        recursive: Bool = false,
        context query: Database.Scope<Model>? = nil,
        _ property1: PropertyArgument<Model, PropertyType1>
    ) async {
        let id = model.id
        let ids: [UUID]
        
        if recursive {
            do {
                ids = try connection
                    .prepare(buildRecursiveExpression(
                        Model.self,
                        name: "updateCTE",
                        rootID: id,
                        base: query?.apply(Model.Schema.baseExpression) ?? Model.Schema.baseExpression
                    ))
                    .map { $0[Model.Schema.id] }
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
            Model.Schema.updatedAt <- Date.now
        ].compact()
        
        let backwardSetters = [
            try? property1.getInverseSetter(model: model),
            Model.Schema.updatedAt <- model.updatedAt
        ].compact()
        
        await history.record(Bijection(
            goForward: { await self.update(Model.self, ids: ids, forwardSetters) },
            goBackward: { await self.update(Model.self, ids: ids, backwardSetters) }
        ))
        
        self.update(Model.self, ids: ids, forwardSetters)
    }
    
    // TODO:  If the model has no matching record in the database, it is created with the updated value.
    internal func update<Model: SchemaBacked>(
        _ model: Model,
        _ setters: [Setter],
        sender: DatabaseMessage.Sender = .userInterface
    ) {
        do {
            update(Model.self, ids: [model.id], setters, sender: sender)
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    internal func update<Model: SchemaBacked>(
        _ type: Model.Type,
        ids: [UUID],
        _ setters: [Setter],
        sender: DatabaseMessage.Sender = .userInterface
    ) {
        do {
            try connection.run(
                Model.Schema.baseExpression
                    .where(ids.contains(Model.Schema.id))
                    .update(setters)
            )
            
            if ids.count == 1 {
                Task.detached {
                    await self.send(.recordChange(type, id: ids.first!, sender: sender))
                }
            }
            else {
                Task.detached {
                    await self.send(.recordsChanged(type, ids: Set(ids), sender: sender))
                }
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    internal func delete<Model: SchemaBacked>(
        _ type: Model.Type,
        _ ids: [UUID],
        sender: DatabaseMessage.Sender
    ) {
        do {
            try connection.run(
                Model.Schema.baseExpression
                    .filter(ids.contains(Model.Schema.id))
                    .delete()
            )
            
            Task.detached {
                await self.send(.recordsDeleted(type, ids: Set(ids)))
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func delete<Model: SchemaBacked>(_ type: Model.Type, _ id: UUID) {
        do {
            try connection.run(
                Model.Schema.baseExpression
                    .filter(Model.Schema.id == id)
                    .delete()
            )
            
            Task.detached {
                await self.send(.recordDeleted(type, id: id))
            }
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
        
    public func purgeRecentlyDeleted<Model: SchemaBacked>(_ type: Model.Type) {
        do {
            try connection.run(
                Model.Schema.baseExpression
                    .filter(Model.Schema.deletedAt < 30.days.ago)
                    .delete()
            )
        }
        catch {
            // do something to broad cast the error to both you and the user
            print(error)
            print("\(#file):\(#function):\(#line)")
        }
    }
    
    private func buildRecursiveExpression<Model: SchemaBacked & RecursiveData>(_ type: Model.Type, name: String, rootID: UUID?, base: SQLite.Table) -> SQLite.Table {
        let cte = Table(name)
                    
        let compoundQuery = base
            .where(base[SQLite.Expression<UUID?>("id")] == rootID)
            .union(
                cte.join(base, on: cte[SQLite.Expression<UUID>("id")] == base[SQLite.Expression<UUID>("parentID")])
                   .select(base[*])
            )
        
        return cte.with(cte, recursive: true, as: compoundQuery)
    }
    
    private func buildRecursiveExpression<Model: SchemaBacked & RecursiveData>(_ type: Model.Type, ids: Set<UUID>, base: SQLite.Table) -> SQLite.Table {
        let cte = Table("cte")
                    
        let compoundQuery = base
            .where(ids.contains(base[SQLite.Expression<UUID?>("id")]))
            .union(
                cte.join(base, on: cte[SQLite.Expression<UUID>("id")] == base[SQLite.Expression<UUID>("parentID")])
                   .select(base[*])
            )
        
        return cte.with(cte, recursive: true, as: compoundQuery)
    }
}

public extension EnvironmentValues {
    @Entry var database: Database? = nil
}
