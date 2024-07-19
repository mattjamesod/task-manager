import AsyncAlgorithms
import SQLite
import SwiftUI

@MainActor
public protocol DatabaseDrivenState {
    associatedtype ModelType: SchemaBacked
    func addOrUpdate(task: ModelType)
    func remove(with id: Int)
}

extension DatabaseDrivenState {
    func receive(syncEvent: QueryMonitor<Self>.SyncResult) {
        switch syncEvent {
        case .addOrUpdate(let model): self.addOrUpdate(task: model)
        case .remove(let id): self.remove(with: id)
        }
    }
}

public actor QueryMonitor<StateContainer: DatabaseDrivenState> {
    private let query: Database.Query
    private var registeredStateContainers: [StateContainer] = []
    
    public init(of query: Database.Query) {
        self.query = query
    }
    
    public func fetch(from database: Database) async  -> [StateContainer.ModelType] {
        await database.fetch(StateContainer.ModelType.self, query: self.query)
    }
    
    public func keepSynchronised(state: StateContainer) {
        registeredStateContainers.append(state)
    }
    
    public enum SyncResult: Sendable {
        case addOrUpdate(StateContainer.ModelType)
        case remove(_ id: Int)
    }
    
    public func beginMonitoring(_ database: Database) async {
        let events = await StateContainer.ModelType.messageHandler.subscribe()
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                for container in registeredStateContainers {
                    await container.receive(syncEvent: sync(id: id, with: database))
                }
            }
        }
    }
    
    private func sync(id: Int, with database: Database) async -> SyncResult {
        guard let model = await fetch(id: id, from: database) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    private func fetch(id: Int, from database: Database) async -> StateContainer.ModelType? {
        await database.fetch(StateContainer.ModelType.self, id: id, context: self.query)
    }
}

extension Database {
    public enum Query: Sendable {
        case allActiveTasks
        case deletedTasks
        
        var tableExpression: SQLite.Table{
            switch self {
            case .allActiveTasks: Schema.Tasks.tableExpression
                    .filter(Schema.Tasks.completedAt == nil && Schema.Tasks.deletedAt == nil)
                    .order(Schema.Tasks.createdAt.asc)
            case .deletedTasks: Schema.Tasks.tableExpression
                    .filter(Schema.Tasks.deletedAt != nil)
                    .order(Schema.Tasks.deletedAt.asc)
            }
        }
    }
}
