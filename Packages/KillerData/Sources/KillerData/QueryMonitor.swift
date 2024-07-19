import AsyncAlgorithms
import SQLite
import SwiftUI
import KillerModels

@MainActor
public protocol StateContainerizable {
    associatedtype ModelType: SchemaBacked
    func addOrUpdate(model: ModelType)
    func remove(with id: Int)
}

@MainActor
public protocol RecursiveStateContainerizable: StateContainerizable {
    associatedtype ModelType: SchemaBacked & RecursiveData
    func addOrUpdate(modelTree: Node<ModelType>)
}

public enum RecursiveSyncResult<StateContainer: RecursiveStateContainerizable>: Sendable {
    case addOrUpdate(Node<StateContainer.ModelType>)
    case remove(_ id: Int)
}

public enum SyncResult<StateContainer: StateContainerizable>: Sendable {
    case addOrUpdate(StateContainer.ModelType)
    case remove(_ id: Int)
}

public actor QueryMonitor<StateContainer: StateContainerizable> {
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
    
    public func beginMonitoring(_ database: Database) async {
        let events = await StateContainer.ModelType.messageHandler.subscribe()
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                await syncRecordChange(id: id, with: database)
            }
        }
    }
    
    private func syncRecordChange(id: Int, with database: Database) async {
        let syncResult = await sync(id: id, with: database)
        
        for container in registeredStateContainers {
            switch syncResult {
                case .addOrUpdate(let model):
                    await container.addOrUpdate(model: model)
                case .remove(let id):
                    await container.remove(with: id)
            }
        }
    }
    
    private func sync(id: Int, with database: Database) async -> SyncResult<StateContainer> {
        guard let model = await fetch(id: id, from: database) else {
            return .remove(id)
        }
        
        return .addOrUpdate(model)
    }
    
    private func fetch(id: Int, from database: Database) async -> StateContainer.ModelType? {
        await database.pluck(StateContainer.ModelType.self, id: id, context: self.query)
    }
}

//public actor RecursiveQueryMonitor<StateContainer: RecursiveStateContainerizable> {
//    private let query: Database.Query
//    private var registeredStateContainers: [StateContainer] = []
//    
//    public init(of query: Database.Query) {
//        self.query = query
//    }
//    
//    public func fetch(from database: Database) async  -> [StateContainer.ModelType] {
//        await database.fetch(StateContainer.ModelType.self, query: self.query)
//    }
//    
//    public func keepSynchronised(state: StateContainer) {
//        registeredStateContainers.append(state)
//    }
//    
//    public func beginMonitoring(_ database: Database) async {
//        let events = await StateContainer.ModelType.messageHandler.subscribe()
//        
//        for await event in events {
//            switch event {
//            case .recordChange(let id):
//                await syncRecordChange(id: id, with: database)
//            }
//        }
//    }
//    
//    private func syncRecordChange(id: Int, with database: Database) async {
//        let syncResult = await sync(id: id, with: database)
//        
//        for container in registeredStateContainers {
//            switch syncResult {
//                case .addOrUpdate(let tree):
//                    await container.addOrUpdate(modelTree: tree)
//                case .remove(let id):
//                    await container.remove(with: id)
//            }
//        }
//    }
//    
//    private func sync(id: Int, with database: Database) async -> RecursiveSyncResult<StateContainer> {
//        guard let model = await fetch(id: id, from: database) else {
//            return .remove(id)
//        }
//        
//        return .addOrUpdate(model)
//    }
//    
//    private func fetch(id: Int, from database: Database) async -> StateContainer.ModelType? {
//        await database.fetch(StateContainer.ModelType.self, id: id, context: self.query)
//    }
//}

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
