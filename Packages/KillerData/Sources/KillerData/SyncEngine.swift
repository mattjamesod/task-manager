

@MainActor
public protocol SynchronisedStateContainer {
    associatedtype ModelType: SchemaBacked
    func addOrUpdate(model: ModelType)
    func addOrUpdate(models: [ModelType])
    func remove(with id: Int)
    func remove(with ids: Set<Int>)
}

public enum SyncResult<StateContainer: SynchronisedStateContainer>: Sendable {
    case addOrUpdate(StateContainer.ModelType)
    case addOrUpdateMany([StateContainer.ModelType])
    case remove(_ id: Int)
    case removeMany(_ ids: Set<Int>)
}

actor SyncEngine<Container: SynchronisedStateContainer> {
    let database: Database
    let query: Database.Query
    
    init(for database: Database, context query: Database.Query) {
        self.database = database
        self.query = query
    }
    
    func sync(_ id: Int) async -> SyncResult<Container> {
        guard let model = await fetch(id) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    func sync(_ ids: Set<Int>) async -> [SyncResult<Container>] {
        var results: [SyncResult<Container>] = []
        
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
    
    private func fetch(_ id: Int) async -> Container.ModelType? {
        await database.pluck(Container.ModelType.self, id: id, context: query)
    }
    
    private func fetch(_ ids: Set<Int>) async -> [Container.ModelType] {
        await database.fetch(Container.ModelType.self, ids: ids, context: query)
    }
}
