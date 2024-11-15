import Foundation
import KillerModels
import CloudKit

actor CloudKitClient {
    enum ResponseError: Error {
        case notLoggedIn
        case cloud(CKError)
        case other(Error)
    }
    
    private let localDatabase: Database
    private let cloudDatabase: CKDatabase
    
    init(localDatabase: Database, cloudDatabase: CKDatabase) {
        self.localDatabase = localDatabase
        self.cloudDatabase = cloudDatabase
    }

    func handleRecordChanged(_ id: KillerTask.ID) async throws(ResponseError) {
        print("CK handleRecordChanged: \(id)")
        
        guard let localRecord = await fetch(id) else { return }
        
        let cloudRecord = try await findOrCreateCloudRecord(with: id)
        
        cloudRecord.setValuesForKeys([
            "id": localRecord.id,
            "body": localRecord.body,
            "completedAt": localRecord.completedAt,
            "parentID": localRecord.parentID,
            "createdAt": localRecord.createdAt,
            "updatedAt": localRecord.updatedAt,
            "deletedAt": localRecord.deletedAt,
        ])
        
        try await cloudSave(cloudRecord)
    }
    
    func handleRecordsChanged(_ ids: Set<KillerTask.ID>) async {
        print("CK handleRecordsChanged: \(ids)")
    }
    
    func handleRecordDeleted(_ id: KillerTask.ID) async {
        print("CK handleRecordDeleted: \(id)")
    }
    
    // MARK: - local fetch methods
    
    private func fetch(_ id: Int) async -> KillerTask? {
        await localDatabase.pluck(KillerTask.self, id: id)
    }
    
    private func fetch(_ ids: Set<Int>) async -> [KillerTask] {
        await localDatabase.fetch(KillerTask.self, ids: ids)
    }
    
    // MARK: - cloud fetch methods
    
    private func cloudID(for localID: Int) -> CKRecord.ID {
        CKRecord.ID(recordName: String(localID))
    }
    
    private func findOrCreateCloudRecord(with id: Int) async throws(ResponseError) -> CKRecord {
        if let record = try await cloudFetch(id) {
            record
        }
        else {
            CKRecord(recordType: "KillerTask", recordID:  self.cloudID(for: id))
        }
        
    }
    
    private func cloudFetch(_ localID: Int) async throws(ResponseError) -> CKRecord? {
        do {
            return try await cloudDatabase.record(for: self.cloudID(for: localID))
        }
        catch {
            guard let cloudError = error as? CKError else {
                throw ResponseError.other(error)
            }
            
            if cloudError.code == .unknownItem {
                // this is fine - there's no way to fetch a record if it exists and return
                // nil otherwise, so we're using this error as behaviour logic smh
                return nil
            }
            
            if cloudError.code == .accountTemporarilyUnavailable {
                // the user is not logged in to an iCloud account. We should have caught this
                // earlier, but if we didn't, the caller knows what to do
                throw ResponseError.notLoggedIn
            }
            
            throw ResponseError.cloud(cloudError)
        }
    }
    
    private func cloudSave(_ record: CKRecord) async throws(ResponseError) {
        do {
            try await cloudDatabase.save(record)
        }
        catch {
            guard let cloudError = error as? CKError else {
                throw ResponseError.other(error)
            }
            
            if cloudError.code == .accountTemporarilyUnavailable {
                // the user is not logged in to an iCloud account. We should have caught this
                // earlier, but if we didn't, the caller knows what to do
                throw ResponseError.notLoggedIn
            }
            
            throw ResponseError.cloud(cloudError)
        }
    }
}
