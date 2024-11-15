import Foundation
import KillerModels
import CloudKit

actor CloudKitClient {
    private let localDatabase: Database
    private let cloudDatabase: CKDatabase
    
    init(localDatabase: Database, cloudDatabase: CKDatabase) {
        self.localDatabase = localDatabase
        self.cloudDatabase = cloudDatabase
    }

    func handleRecordChanged(_ id: KillerTask.ID) async {
        print("CK handleRecordChanged: \(id)")
        
        guard let localRecord = await fetch(id) else { return }
        
        let cloudID = CKRecord.ID(recordName: String(localRecord.id))
        let cloudRecord = CKRecord(recordType: "KillerTask", recordID: cloudID)
        
        do {
            let foundCloudRecord = try await cloudDatabase.record(for: cloudID)
            print(foundCloudRecord)
        }
        catch {
            print(error as? CKError)
        }
        
        cloudRecord.setValuesForKeys([
            "id": localRecord.id,
            "body": localRecord.body,
            "completedAt": localRecord.completedAt,
            "parentID": localRecord.parentID,
            "createdAt": localRecord.createdAt,
            "updatedAt": localRecord.updatedAt,
            "deletedAt": localRecord.deletedAt,
        ])
        
//            do {
//                try await cloudDatabase.save(cloudRecord)
//            }
//            catch {
//                print(error.localizedDescription)
//            }
    }
    
    func handleRecordsChanged(_ ids: Set<KillerTask.ID>) async {
        print("CK handleRecordsChanged: \(ids)")
    }
    
    func handleRecordDeleted(_ id: KillerTask.ID) async {
        print("CK handleRecordDeleted: \(id)")
    }
    
    // MARK: - local fetch methods
    // to erase knowledge of the Query from the fetch method
    
    private func fetch(_ id: Int) async -> KillerTask? {
        await localDatabase.pluck(KillerTask.self, id: id)
    }
    
    private func fetch(_ ids: Set<Int>) async -> [KillerTask] {
        await localDatabase.fetch(KillerTask.self, ids: ids)
    }
    
    // MARK: - cloud fetch methods
    
    private func cloudFetch(_ id: Int) async throws -> CKRecord? {
        let cloudID = CKRecord.ID(recordName: String(id))
        
        do {
            return try await cloudDatabase.record(for: cloudID)
        }
        catch {
            guard let cloudError = error as? CKError else { throw error }
            
            if cloudError.code == .unknownItem {
                // this is fine - there's no way to fetch a record if it exists and return
                // nil otherwise, so we're using this error as behaviour logic smh
                
                return nil
            }
            
            // TODO: mark the local record as requiring a CK update
            
            return nil
        }
    }
}
