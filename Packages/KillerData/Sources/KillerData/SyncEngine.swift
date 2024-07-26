
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
        var results: [SyncResult<ModelType>] = []
        
        let models = await fetch(ids)
        
        switch models.count {
            case 0: break
            case 1: results.append(.addOrUpdate(models.first!))
            default: results.append(.addOrUpdateMany(models))
        }
        
        let missingIDs = ids.subtracting(models.compactMap(\.id))
        
        switch missingIDs.count {
            case 0: break
            case 1: results.append(.remove(missingIDs.first!))
            default: results.append(.removeMany(missingIDs))
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
