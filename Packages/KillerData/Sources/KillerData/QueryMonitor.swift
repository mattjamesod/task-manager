import SQLite
import KillerModels

// TODO: sync service for all these private methods

public actor QueryMonitor<StateContainer: SynchronisedStateContainer & Identifiable> {
    private let query: Database.Query
    
    public init(of query: Database.Query) {
        self.query = query
    }
    
    private var registeredStateContainers: [StateContainer] = []
    
    public func keepSynchronised(state: StateContainer) {
        registeredStateContainers.append(state)
    }
    
    public func deregister(state: StateContainer) {
        guard let index = registeredStateContainers.firstIndex(where: { $0.id == state.id }) else { return }
        registeredStateContainers.remove(at: index)
    }
    
    public func beginMonitoring(_ database: Database) async {
        let events = await StateContainer.ModelType.messageHandler.subscribe()
        let syncEngine = SyncEngine<StateContainer>(for: database, context: self.query)
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                await push(syncResult: await syncEngine.sync(id))
            case .recordsChanged(let ids):
                for result in await syncEngine.sync(ids) {
                    await push(syncResult: result)
                }
            }
        }
    }
    
    private func push(syncResult: SyncResult<StateContainer>) async {
        for container in registeredStateContainers {
            switch syncResult {
                case .addOrUpdate(let model):
                    await container.addOrUpdate(model: model)
                case .addOrUpdateMany(let models):
                    await container.addOrUpdate(models: models)
                case .remove(let id):
                    await container.remove(with: id)
                case .removeMany(let ids):
                    await container.remove(with: ids)
            }
        }
    }
    
    // MARK: - fetch methods
    // to erase knowledge of the Query from the fetch method
    
    public func fetch(from database: Database) async  -> [StateContainer.ModelType] {
        await database.fetch(StateContainer.ModelType.self, query: self.query)
    }
    
    public func fetchChildren(from database: Database, id: Int?) async  -> [StateContainer.ModelType] where StateContainer.ModelType: RecursiveData {
        await database.fetchChildren(StateContainer.ModelType.self, id: id, context: self.query)
    }
}

extension Database {
    public struct Query: Sendable {
        let baseExpression = Schema.Tasks.tableExpression
        
        internal init(tableExpression: @escaping (SQLite.Table) -> (SQLite.Table)) {
            self.apply = tableExpression
        }
        
        public static let allActiveTasks: Query = .init { base in
            let table = Schema.Tasks.tableExpression
            
            return base
                .filter(table[Schema.Tasks.completedAt] == nil && table[Schema.Tasks.deletedAt] == nil)
                .order(table[Schema.Tasks.createdAt].asc)
        }
        
        public static let deletedTasks: Query = .init { base in
            base
                .filter(Schema.Tasks.deletedAt != nil)
                .order(Schema.Tasks.deletedAt.asc)
        }
        
        let apply: (SQLite.Table) -> SQLite.Table
    }
}
