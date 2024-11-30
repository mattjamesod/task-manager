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
                    do {
                        switch message {
                        case .recordChange(let recordType, let id):
                            guard let conformingRecordType = recordType as? any (SchemaBacked & CloudKitBacked).Type else { return }
                            guard let record = await localDatabase.pluck(conformingRecordType, id: id) else { continue }
                            try await engine.handleRecordChanged(record)
                        case .recordsChanged(let ids):
                            let records = await localDatabase.fetch(KillerTask.self, ids: ids)
                            try await engine.handleRecordsChanged(records)
                        case .recordDeleted(let id):
                            guard let record = await localDatabase.pluck(KillerTask.self, id: id) else { return }
                            try await engine.handleRecordDeleted(record)
                        }
                    }
                    catch {
                        print(error.localizedDescription)
                        // TODO: log response error
                        // TODO: mark the local record as requiring a CK update
                    }
                }
            })
        }
        
        private func handle(message: DatabaseMessage) async {
            do {
                switch message {
                case .recordChange(let type, let id):
                    guard
                        let conformingType = type as? any (SchemaBacked & CloudKitBacked).Type,
                        let record = await localDatabase.pluck(conformingType, id: id)
                    else { return }
                    
                    try await engine.handleRecordChanged(record)
                case .recordsChanged(let ids):
                    let records = await localDatabase.fetch(KillerTask.self, ids: ids)
                    try await engine.handleRecordsChanged(records)
                case .recordDeleted(let id):
                    guard let record = await localDatabase.pluck(KillerTask.self, id: id) else { return }
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


//protocol ProtocolA {
//    func someMethodA()
//}
//
//protocol ProtocolB {
//    func someMethodB()
//}
//
//struct MyStruct: ProtocolA, ProtocolB {
//    let id: Int
//    
//    func someMethodA() { print("A") }
//    func someMethodB() { print("B") }
//}
//
//class MyClass {
//    func doThingIfConforms(_ type: any ProtocolA.Type, id: Int) {
//        let instance = fetch(type, id: 5)
//        doThing(instance: instance)
//    }
//    
//    private func doThing<ConcreteTypeB: ProtocolB>(instance: ConcreteTypeB) {
//        
//    }
//    
//    private func fetch<ConcreteTypeA: ProtocolA>(_ type: ConcreteTypeA.Type, id: Int) -> ConcreteTypeA {
//        fatalError() // implementation irrelevant
//    }
//}
