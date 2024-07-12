import AsyncAlgorithms
import SQLite

public actor QueryMonitor<ModelType: SchemaBacked> {
    private let query: Database.Query
    public var syncEvents: AsyncChannel<SyncResult> = .init()
    
    public init(of query: Database.Query) {
        self.query = query
    }
    
    public func fetch(from database: Database) async  -> [ModelType] {
        await database.fetch(ModelType.self, query: self.query)
    }
    
    public enum SyncResult: Sendable {
        case addOrUpdate(ModelType)
        case remove(_ id: Int)
    }
    
    public func listenForTasks(on database: Database) async {
        let events = await ModelType.messageHandler.subscribe()
        
        for await event in events {
            switch event {
            case .recordChange(let id):
                await syncEvents.send(sync(id: id, with: database))
            }
        }
    }
    
    private func sync(id: Int, with database: Database) async -> SyncResult {
        guard let task = await fetch(id: id, from: database) else {
            return .remove(id)
        }
        
        return .addOrUpdate(task)
    }
    
    private func fetch(id: Int, from database: Database) async -> ModelType? {
        await database.fetch(ModelType.self, id: id, context: self.query)
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
