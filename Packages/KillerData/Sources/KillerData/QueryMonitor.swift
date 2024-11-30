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
    
    public func register(container: StateContainer) {
        self.log("QM registered new container")
        registeredStateContainers.append(container)
    }
    
    public func deregister(container: StateContainer) {
        self.log("QM tried to deregister container...")
        guard let index = registeredStateContainers.firstIndex(where: { $0.id == container.id }) else { return }
        self.log("...and succeeded")
        registeredStateContainers.remove(at: index)
    }
    
    public func waitForChanges(_ query: Database.Scope, on database: Database) async {
        self.log("started monitoring")
        dbMessageThread = await StateContainer.ModelType.messageHandler.subscribe()
        let syncEngine = ViewSyncEngine<StateContainer.ModelType>(for: database, context: query)
        
        self.monitorTask = Task {
            guard let thread = self.dbMessageThread else { return }
            for await event in thread.events {
                self.log("received event: \(event)")
                
                switch event {
                case .recordChange(let type, let id):
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
    }
    
    public func waitForChanges(_ query: Database.Scope, recursive: Bool, on database: Database) async where StateContainer.ModelType: RecursiveData {
        self.log("started monitoring")
        dbMessageThread = await StateContainer.ModelType.messageHandler.subscribe()
        let syncEngine = ViewSyncEngine<StateContainer.ModelType>(for: database, context: query)
        
        self.monitorTask = Task {
            guard let thread = self.dbMessageThread else { return }
            for await event in thread.events {
                self.log("received event: \(event)")
                switch event {
                case .recordChange(let type, let id):
                    for result in await syncEngine.sync(id) {
                        await push(syncResult: result)
                    }
                case .recordsChanged(let ids):
                    for result in await syncEngine.sync(ids) {
                        await push(syncResult: result)
                    }
                case .recordDeleted(let id):
                    await push(syncResult: .remove(id))
                }
            }
        }
    }
    
    public func stopMonitoring() async {
        self.log("stopped monitoring")
        guard let dbMessageThread else { return }
        self.monitorTask?.cancel()
        self.monitorTask = nil
        await StateContainer.ModelType.messageHandler.unsubscribe(dbMessageThread)
        self.dbMessageThread = nil
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
