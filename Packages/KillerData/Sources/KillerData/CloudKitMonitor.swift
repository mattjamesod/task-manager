import KillerModels
import Foundation
import CloudKit

extension Database {
    public actor CloudKitMonitor {
        init(schemaDescription: SchemaDescription) {
            self.schema = schemaDescription
        }
        
        private let schema: SchemaDescription
        private var monitorTask: Task<Void, Never>? = nil
        private var dbMessageThread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
        
        func waitForChanges(on database: Database) async {
            // get these from schema description
            dbMessageThread = await KillerTask.messageHandler.subscribe()
            
            self.monitorTask = Task {
                guard let thread = self.dbMessageThread else { return }
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
