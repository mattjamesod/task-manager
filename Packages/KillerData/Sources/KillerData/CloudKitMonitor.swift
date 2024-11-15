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
            
            let client = CloudKitClient(
                localDatabase: self.localDatabase,
                cloudDatabase: self.cloudDatabase
            )
            
            for thread in dbMessageThreads {
                self.monitorTasks.append(Task {
                    for await event in thread.events {
                        switch event {
                        case .recordChange(let id):
                            await client.handleRecordChanged(id)
                        case .recordsChanged(let ids):
                            await client.handleRecordsChanged(ids)
                        case .recordDeleted(let id):
                            await client.handleRecordDeleted(id)
                        }
                    }
                })
            }
        }
    }
}
