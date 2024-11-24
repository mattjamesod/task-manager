import KillerModels
import Foundation
import CloudKit

extension Database {
    public actor CloudKitMonitor {
        init(database: Database) {
            self.localDatabase = database
        }
        
        private let localDatabase: Database
        private var monitorTasks: [Task<Void, Never>] = []
        
        private var killerTaskMessages: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
        
        private let syncEngine = CloudKitSyncEngine(
            client: CloudKitClient(
                database: CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
            )
        )
        
        func waitForChanges() async {
            do {
                try await syncEngine.ensureRemoteSchemaSetup()
            }
            catch {
                // TODO: log response error
                // TODO: propagate to user?
                print(error.localizedDescription)
                return
            }
            
            killerTaskMessages = await KillerTask.messageHandler.subscribe()
            
            self.monitorTasks.append(Task {
                guard let thread = self.killerTaskMessages else { return }
                for await event in thread.events {
                    await handle(message: event, recordType: KillerTask.self)
                }
            })
        }
        
        private func handle<ModelType: SchemaBacked & CloudKitBacked>(
            message: DatabaseMessage,
            recordType: ModelType.Type
        ) async {
            do {
                switch message {
                case .recordChange(let id):
                    guard let record = await localDatabase.pluck(ModelType.self, id: id) else { return }
                    try await syncEngine.handleRecordChanged(record)
                case .recordsChanged(let ids):
                    let records = await localDatabase.fetch(ModelType.self, ids: ids)
                    try await syncEngine.handleRecordsChanged(records)
                case .recordDeleted(let id):
                    guard let record = await localDatabase.pluck(ModelType.self, id: id) else { return }
                    try await syncEngine.handleRecordDeleted(record)
                }
            }
            catch {
                print(error.localizedDescription)
                // TODO: log response error
                // TODO: mark the local record as requiring a CK update
            }
        }
    }
}
