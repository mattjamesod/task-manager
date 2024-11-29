import KillerModels
import Foundation
import CloudKit

extension Database {
    public actor CloudKitUploadMonitor {
        init(database: Database) {
            self.localDatabase = database
            self.cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
            self.engine = .init(client: CloudKitClient(database: cloudDatabase))
        }
        
        private let localDatabase: Database
        private let cloudDatabase: CKDatabase
        private let engine: CloudKitUploadEngine
        
        private var monitorTasks: [Task<Void, Never>] = []
        private var killerTaskMessages: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
        
        func waitForLocalChanges() async {
            do {
                try await engine.ensureRemoteSchemaSetup()
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
                    try await engine.handleRecordChanged(record)
                case .recordsChanged(let ids):
                    let records = await localDatabase.fetch(ModelType.self, ids: ids)
                    try await engine.handleRecordsChanged(records)
                case .recordDeleted(let id):
                    guard let record = await localDatabase.pluck(ModelType.self, id: id) else { return }
                    try await engine.handleRecordDeleted(record)
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
