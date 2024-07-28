import KillerModels

@MainActor
public protocol SynchronisedStateContainer: Identifiable, Sendable, AnyObject {
    associatedtype ModelType: SchemaBacked
    func addOrUpdate(model: ModelType)
    func addOrUpdate(models: [ModelType])
    func remove(with id: Int)
    func remove(with ids: Set<Int>)
}

public enum SyncResult<ModelType: Sendable>: Sendable {
    case addOrUpdate(ModelType)
    case addOrUpdateMany([ModelType])
    case remove(_ id: Int)
    case removeMany(_ ids: Set<Int>)
}

actor SyncEngine<ModelType: SchemaBacked> {
    let database: Database
    let query: Database.Query
    
    init(for database: Database, context query: Database.Query) {
        self.database = database
        self.query = query
    }
    
    func sync(_ id: Int) async -> SyncResult<ModelType> {
        guard let model = await fetch(id) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    func sync(_ ids: Set<Int>) async -> [SyncResult<ModelType>] {
        let models = await fetch(ids)
        let missingIDs = ids.subtracting(models.compactMap(\.id))
        
        return compileResults(addOrUpdating: models, removing: missingIDs)
    }
    
    func sync(_ id: Int) async -> [SyncResult<ModelType>] where ModelType: RecursiveData {
        await self.sync(Set<Int>.init([id]))
    }
    
    func sync(_ ids: Set<Int>) async -> [SyncResult<ModelType>] where ModelType: RecursiveData {
        // IDs of all items changed, and all of their recursive children
        let relevantIDs = await database
            .fetchRecursive(ModelType.self, ids: ids)
            .compactMap(\.id)
        
        // all models which are relevant to this event, and which should be shown in any view displaing the context query
        let applicableModels = await database
            .fetch(ModelType.self, context: query)
            .filter { $0.id != nil && relevantIDs.contains($0.id!) }
        
        // all IDs which are relevant to this event, but should not be shown in any reflecting views
        let missingIDs = Set(relevantIDs).subtracting(applicableModels.compactMap(\.id))
        
        return compileResults(addOrUpdating: applicableModels, removing: missingIDs)
    }
    
    private func compileResults(addOrUpdating: [ModelType], removing: Set<Int>) -> [SyncResult<ModelType>] {
        var results: [SyncResult<ModelType>] = []
        
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
    
    private func fetch(_ id: Int) async -> ModelType? {
        await database.pluck(ModelType.self, id: id, context: query)
    }
    
    private func fetch(_ ids: Set<Int>) async -> [ModelType] {
        await database.fetch(ModelType.self, ids: ids, context: query)
    }
}
