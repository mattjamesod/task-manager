import Foundation
import KillerModels

@MainActor
public protocol SynchronisedStateContainer: Identifiable, Sendable, AnyObject {
    associatedtype Model: SchemaBacked & Identifiable
    func addOrUpdate(model: Model)
    func addOrUpdate(models: [Model])
    func remove(with id: UUID)
    func remove(with ids: Set<UUID>)
}

public enum SyncResult<Model: Sendable>: Sendable {
    case addOrUpdate(Model)
    case addOrUpdateMany([Model])
    case remove(_ id: UUID)
    case removeMany(_ ids: Set<UUID>)
}

/// Updates the state of a view from the database, given a list of Models with IDs which should
/// be recalculated

actor ViewSyncEngine<Model: SchemaBacked & Identifiable> {
    let database: Database
    let query: Database.Scope
    
    init(for database: Database, context query: Database.Scope) {
        self.database = database
        self.query = query
    }
    
    func sync(_ id: UUID) async -> SyncResult<Model> {
        guard let model = await fetch(id) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    func sync(_ ids: Set<UUID>) async -> [SyncResult<Model>] {
        let models = await fetch(ids)
        let missingIDs = ids.subtracting(models.compactMap(\.id))
        
        return compileResults(addOrUpdating: models, removing: missingIDs)
    }
    
    func sync(_ id: UUID) async -> [SyncResult<Model>] where Model: RecursiveData {
        await self.sync(Set<UUID>.init([id]))
    }
    
    func sync(_ ids: Set<UUID>) async -> [SyncResult<Model>] where Model: RecursiveData {
        // IDs of all items changed, and all of their recursive children
        let relevantIDs = await database
            .fetchRecursive(Model.self, ids: ids)
            .compactMap(\.id)
        
        // all models which are relevant to this event, and which should be shown in any view displaying the context query
        let applicableModels = await database
            .fetch(Model.self, context: query)
            .filter { $0.id != nil && relevantIDs.contains($0.id) }
        
        // all IDs which are relevant to this event, but should not be shown in any reflecting views
        let missingIDs = Set(relevantIDs).subtracting(applicableModels.compactMap(\.id))
        
        return compileResults(addOrUpdating: applicableModels, removing: missingIDs)
    }
    
    private func compileResults(addOrUpdating: [Model], removing: Set<UUID>) -> [SyncResult<Model>] {
        var results: [SyncResult<Model>] = []
        
        switch addOrUpdating.count {
            case 0: break
            case 1: results.append(.addOrUpdate(addOrUpdating.first!))
            default: results.append(.addOrUpdateMany(addOrUpdating))
        }
        
        switch removing.count {
            case 0: break
            case 1: results.append(.remove(removing.first!))
            default: results.append(.removeMany(removing))
        }
        
        return results
    }
    
    // MARK: - fetch methods
    // to erase knowledge of the Query from the fetch method
    
    private func fetch(_ id: UUID) async -> Model? {
        await database.pluck(Model.self, id: id, context: query)
    }
    
    private func fetch(_ ids: Set<UUID>) async -> [Model] {
        await database.fetch(Model.self, ids: ids, context: query)
    }
}
