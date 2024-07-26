@preconcurrency import SQLite
import KillerModels

public actor QueryMonitor<StateContainer: SynchronisedStateContainer> {
    public init() { }
    
    private var registeredStateContainers: [StateContainer] = []
    
    public func keepSynchronised(state: StateContainer) {
        registeredStateContainers.append(state)
    }
    
    public func deregister(state: StateContainer) {
        guard let index = registeredStateContainers.firstIndex(where: { $0.id == state.id }) else { return }
        registeredStateContainers.remove(at: index)
    }
    
    public func beginMonitoring(_ query: Database.Query, on database: Database) async {
        let events = await StateContainer.ModelType.messageHandler.subscribe()
        let syncEngine = SyncEngine<StateContainer.ModelType>(for: database, context: query)
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                await push(syncResult: await syncEngine.sync(id))
            case .recordsChanged(let ids):
                for result in await syncEngine.sync(ids) {
                    await push(syncResult: result)
                }
            case .recordDeleted(let id):
                await push(syncResult: .remove(id))
            }
        }
    }
    
    private func push(syncResult: SyncResult<StateContainer.ModelType>) async {
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
}

extension Database {
    public struct Query: Sendable {
        let baseExpression = Schema.Tasks.tableExpression
        
        internal init(tableExpression: @escaping @Sendable (SQLite.Table) -> (SQLite.Table)) {
            self.apply = tableExpression
        }
        
        public static let allActiveTasks: Query = .init { base in
            let table = Schema.Tasks.tableExpression
            
            return base
                .filter(table[Schema.Tasks.completedAt] == nil && table[Schema.Tasks.deletedAt] == nil)
                .order(table[Schema.Tasks.createdAt].asc)
        }
        
        public static let orphaned: Query = .init { base in
            let tasks = Schema.Tasks.tableExpression
            let cte = Table("cte")
            
            return base
                .with(cte, as: base.select(Schema.Tasks.id))
                .join(.leftOuter, cte, on: tasks[Schema.Tasks.parentID] == cte[Schema.Tasks.id])
                .select(Schema.Tasks.tableExpression[*])
                .filter(cte[Expression<Int?>("id")] == nil)
        }
        
        public static let deletedTasks: Query = .init { base in
            base
                .filter(Schema.Tasks.deletedAt != nil)
                .order(Schema.Tasks.deletedAt.asc)
        }
        
        let apply: @Sendable (SQLite.Table) -> SQLite.Table
        
        public func compose(with other: Query?) -> Query {
            guard let other else { return self }
            return Query { other.apply(self.apply($0)) }
        }
    }
}

public extension Optional where Wrapped == Database.Query {
    public func compose(with other: Database.Query?) -> Database.Query? {
        guard let other else { return self }
        guard let foundSelf = self else { return other }
        
        return foundSelf.compose(with: other)
    }
}
