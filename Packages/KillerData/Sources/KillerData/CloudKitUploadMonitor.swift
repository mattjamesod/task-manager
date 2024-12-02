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
            
            // recordChangeMessages = await localDatabase.messageHandler.subscribe() ?
            killerTaskMessages = await KillerTask.messageHandler.subscribe()
            
            self.monitorTasks.append(Task {
                guard let thread = self.killerTaskMessages else { return }
                for await message in thread.events {
                    print("cloudKit upload: \(message)")
                    await handle(message)
                }
            })
        }
        
        private func handle(_ message: DatabaseMessage) async {
            do {
                switch message {
                case .recordChange(let localType, let id):
                    guard let recordType = localType.forCloudKit() else { return }
                    guard let record = await localDatabase.pluck(recordType, id: id) else { return }
                    
                    try await engine.handleRecordChanged(record)
                case .recordsChanged(let localType, let ids):
                    guard let recordType = localType.forCloudKit() else { return }
                    let records = await localDatabase.fetch(recordType, ids: ids)
                    
                    let castRecords = records.map(AnyCloudKitBacked.init)
                    
                    try await engine.handleRecordsChanged(castRecords)
                case .recordDeleted(let localType, let id):
                    guard let recordType = localType.forCloudKit() else { return }
                    guard let record = await localDatabase.pluck(recordType, id: id) else { return }
                    
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

