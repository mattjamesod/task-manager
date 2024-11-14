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
            
            for thread in dbMessageThreads {
                self.monitorTasks.append(Task {
                    for await event in thread.events {
                        switch event {
                        case .recordChange(let id):
                            await self.handleRecordChanged(id)
                        case .recordsChanged(let ids):
                            await self.handleRecordsChanged(ids)
                        case .recordDeleted(let id):
                            await self.handleRecordDeleted(id)
                        }
                    }
                })
            }
        }
        
        private func handleRecordChanged(_ id: KillerTask.ID) async {
            print("CK handleRecordChanged: \(id)")
            
            guard let localRecord = await fetch(id) else { return }
            
            let cloudRecord = CKRecord(recordType: "KillerTask")
            
            cloudRecord.setValuesForKeys([
                "id": localRecord.id,
                "body": localRecord.body,
                "completedAt": localRecord.completedAt,
                "parentID": localRecord.parentID,
                "createdAt": localRecord.createdAt,
                "updatedAt": localRecord.updatedAt,
                "deletedAt": localRecord.deletedAt,
            ])
            
            do {
                try await cloudDatabase.save(cloudRecord)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        
        private func handleRecordsChanged(_ ids: Set<KillerTask.ID>) async {
            print("CK handleRecordsChanged: \(ids)")
        }
        
        private func handleRecordDeleted(_ id: KillerTask.ID) async {
            print("CK handleRecordDeleted: \(id)")
        }
        
        // MARK: - fetch methods
        // to erase knowledge of the Query from the fetch method
        
        private func fetch(_ id: Int) async -> KillerTask? {
            await localDatabase.pluck(KillerTask.self, id: id)
        }
        
        private func fetch(_ ids: Set<Int>) async -> [KillerTask] {
            await localDatabase.fetch(KillerTask.self, ids: ids)
        }
    }
}
