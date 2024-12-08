import KillerModels
import Foundation
import CloudKit

extension Database {
    public actor CloudKitUploadMonitor {
        init(database: Database) {
            self.localDatabase = database
            self.engine = .init()
        }
        
        private let localDatabase: Database
        private let engine: CloudKitUploadEngine
        
        private var monitorTasks: [Task<Void, Never>] = []
        private var recordChangeMessages: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
        
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
            
            recordChangeMessages = await localDatabase.subscribe(to: .userInterface)
            
            self.monitorTasks.append(Task {
                guard let thread = self.recordChangeMessages else { return }
                for await message in thread.events {
                    await handle(message)
                }
            })
        }
        
        private func handle(_ message: DatabaseMessage) async {
            do {
                switch message {
                case .recordChange(let localType, let id, let _):
                    guard let recordType = localType as? any DataBacked.Type else { return }
                    guard let record = await localDatabase.pluck(recordType, id: id) else { return }
                    
                    try await engine.handleRecordChanged(record)
                case .recordsChanged(let localType, let ids, let _):
                    guard let recordType = localType as? any DataBacked.Type else { return }
                    let records = await localDatabase.fetch(recordType, ids: ids)
                    
                    let castRecords = records.map(AnyCloudKitBacked.init)
                    
                    try await engine.handleRecordsChanged(castRecords)
                case .recordDeleted(let localType, let id, let _):
                    guard let recordType = localType as? any DataBacked.Type else { return }
                    guard let record = await localDatabase.pluck(recordType, id: id) else { return }
                    
                    try await engine.handleRecordDeleted(record)
                case .recordsDeleted(let localType, let ids, let _):
                    guard let recordType = localType as? any DataBacked.Type else { return }
                    let records = await localDatabase.fetch(recordType, ids: ids)
                    
                    let castRecords = records.map(AnyCloudKitBacked.init)
                    
                    try await engine.handleRecordsDeleted(castRecords)
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

