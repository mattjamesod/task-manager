@preconcurrency import SQLite
import Foundation
import Logging
import KillerModels

public actor QueryMonitor<StateContainer: SynchronisedStateContainer>: CustomConsoleLogger {
    public init() {  }

    public let logToConsole: Bool = false
    
    private var monitorTask: Task<Void, Never>? = nil
    private var dbMessageThread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
    private var registeredStateContainers: [StateContainer] = []
    
    public var isMonitoring: Bool {
        dbMessageThread != nil
    }
    
    public func register(container: StateContainer) {
        registeredStateContainers.append(container)
    }
    
    public func deregister(container: StateContainer) {
        guard let index = registeredStateContainers.firstIndex(where: { $0.id == container.id }) else { return }
        registeredStateContainers.remove(at: index)
    }
    
    public func waitForChanges(_ query: Database.Scope<StateContainer.Model>, on database: Database) async {
        self.log("started monitoring")
        dbMessageThread = await database.subscribe(to: StateContainer.Model.self)
        let syncEngine = ViewSyncEngine<StateContainer.Model>(for: database, context: query)
        
        self.monitorTask = Task {
            guard let thread = self.dbMessageThread else { return }
            for await event in thread.events {
                print("received event: \(event)")
                
                switch event {
                case .recordChange(let _, let id, let _):
                    await push(syncResult: await syncEngine.sync(id))
                case .recordsChanged(let _, let ids, let _):
                    for result in await syncEngine.sync(ids) {
                        await push(syncResult: result)
                    }
                case .recordDeleted(let _, let id, let _):
                    await push(syncResult: .remove(id))
                case .recordsDeleted(let _, let ids, let _):
                    await push(syncResult: .removeMany(ids))
                }
            }
        }
    }
    
    public func waitForChanges(_ query: Database.Scope<StateContainer.Model>, recursive: Bool, on database: Database) async where StateContainer.Model: RecursiveData {
        self.log("started monitoring")
        dbMessageThread = await database.subscribe(to: StateContainer.Model.self)
        let syncEngine = ViewSyncEngine<StateContainer.Model>(for: database, context: query)
        
        self.monitorTask = Task {
            guard let thread = self.dbMessageThread else { return }
            for await event in thread.events {
                self.log("received event: \(event)")
                switch event {
                case .recordChange(let _, let id, let _):
                    for result in await syncEngine.sync(id) {
                        await push(syncResult: result)
                    }
                case .recordsChanged(let _, let ids, let _):
                    for result in await syncEngine.sync(ids) {
                        await push(syncResult: result)
                    }
                case .recordDeleted(let _, let id, let _):
                    await push(syncResult: .remove(id))
                case .recordsDeleted(let _, let ids, let _):
                    await push(syncResult: .removeMany(ids))
                }
            }
        }
    }
    
    public func stopMonitoring(database: Database) async {
        self.log("stopped monitoring")
        guard let dbMessageThread else { return }
        self.monitorTask?.cancel()
        self.monitorTask = nil
        await database.unsubscribe(dbMessageThread)
        self.dbMessageThread = nil
    }
    
    private func push(syncResult: SyncResult<StateContainer.Model>) async {
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
