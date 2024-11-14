import KillerModels
import Foundation
import CloudKit

extension Database {
    public actor CloudKitMonitor {
        init(schemaDescription: SchemaDescription) {
            self.schema = schemaDescription
        }
        
        private let schema: SchemaDescription
        private var monitorTasks: [Task<Void, Never>] = []
        private var dbMessageThreads: [AsyncMessageHandler<DatabaseMessage>.Thread] = []
        
        func waitForChanges(on database: Database) async {
            dbMessageThreads = await schema.subscribeToAll()
            
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
        }
        
        private func handleRecordsChanged(_ ids: Set<KillerTask.ID>) async {
            print("CK handleRecordsChanged: \(ids)")
        }
        
        private func handleRecordDeleted(_ id: KillerTask.ID) async {
            print("CK handleRecordDeleted: \(id)")
        }
    }
}
