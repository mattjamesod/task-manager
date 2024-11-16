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
        private var dbMessageThreads: [AsyncMessageHandler<DatabaseMessage>.Thread] = []
        
        private let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
        
        func waitForChanges() async {
            dbMessageThreads = await localDatabase.schema.subscribeToAll()
            
            let client = CloudKitClient(cloudDatabase: self.cloudDatabase)
            
            for thread in dbMessageThreads {
                self.monitorTasks.append(Task {
                    for await event in thread.events {
                        do {
                            switch event {
                            case .recordChange(let id):
                                guard let record = await fetch(id) else { continue }
                                try? await client.handleRecordChanged(record)
                            case .recordsChanged(let ids):
                                let records = await fetch(ids)
                                await client.handleRecordsChanged(records)
                            case .recordDeleted(let id):
                                guard let record = await fetch(id) else { continue }
                                await client.handleRecordDeleted(record)
                            }
                        }
                        catch {
                            // TODO: log response error
                            // TODO: mark the local record as requiring a CK update
                        }
                    }
                })
            }
        }
        
        // MARK: - local fetch methods
        
        private func fetch(_ id: Int) async -> KillerTask? {
            await localDatabase.pluck(KillerTask.self, id: id)
        }
        
        private func fetch(_ ids: Set<Int>) async -> [KillerTask] {
            await localDatabase.fetch(KillerTask.self, ids: ids)
        }
    }
}
