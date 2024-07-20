import AsyncAlgorithms
import SQLite
import SwiftUI
import KillerModels

@MainActor
public protocol StateContainerizable {
    associatedtype ModelType: SchemaBacked
    func addOrUpdate(model: ModelType)
    func addOrUpdate(models: [ModelType])
    func remove(with id: Int)
    func remove(with ids: Set<Int>)
}

public enum SyncResult<StateContainer: StateContainerizable>: Sendable {
    case addOrUpdate(StateContainer.ModelType)
    case addOrUpdateMany([StateContainer.ModelType])
    case remove(_ id: Int)
    case removeMany(_ ids: Set<Int>)
}

// TODO: sync service for all these private methods

public actor QueryMonitor<StateContainer: StateContainerizable & Identifiable> {
    private let query: Database.Query
    private var registeredStateContainers: [StateContainer] = []
    
    public init(of query: Database.Query) {
        self.query = query
    }
    
    public func fetch(from database: Database) async  -> [StateContainer.ModelType] {
        await database.fetch(StateContainer.ModelType.self, query: self.query)
    }
    
    public func fetchChildren(from database: Database, id: Int?) async  -> [StateContainer.ModelType] where StateContainer.ModelType: RecursiveData {
        await database.fetchChildren(StateContainer.ModelType.self, id: id, context: self.query)
    }
    
    public func keepSynchronised(state: StateContainer) {
        registeredStateContainers.append(state)
    }
    
    public func deregister(state: StateContainer) {
        guard let index = registeredStateContainers.firstIndex(where: { $0.id == state.id }) else { return }
        
    }
    
    public func beginMonitoring(_ database: Database) async {
        let events = await StateContainer.ModelType.messageHandler.subscribe()
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                await push(syncResult: await sync(id: id, with: database))
            case .recordsChanged(let ids):
                for result in await sync(ids: ids, with: database) {
                    await push(syncResult: result)
                }
            }
        }
    }
    
    private func sync(id: Int, with database: Database) async -> SyncResult<StateContainer> {
        guard let model = await fetch(id: id, from: database) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    private func sync(ids: Set<Int>, with database: Database) async -> [SyncResult<StateContainer>] {
        var results: [SyncResult<StateContainer>] = []
        
        let models = await fetch(ids: ids, from: database)
        
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
    
    private func fetch(id: Int, from database: Database) async -> StateContainer.ModelType? {
        await database.pluck(StateContainer.ModelType.self, id: id, context: self.query)
    }
    
    private func fetch(ids: Set<Int>, from database: Database) async -> [StateContainer.ModelType] {
        await database.fetch(StateContainer.ModelType.self, ids: ids, context: self.query)
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
