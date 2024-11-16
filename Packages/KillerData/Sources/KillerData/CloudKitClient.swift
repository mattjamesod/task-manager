import Foundation
import KillerModels
import CloudKit

protocol CloudKitBacked {
    var cloudID: CKRecord.ID { get }
    var cloudBackedProperties: [String : Any] { get }
}

extension KillerTask: CloudKitBacked {
    var cloudID: CKRecord.ID {
        CKRecord.ID(recordName: String(self.id))
    }
    
    var cloudBackedProperties: [String : Any] { [
        "id": self.id,
        "body": self.body,
        "completedAt": self.completedAt,
        "parentID": self.parentID,
        "createdAt": self.createdAt,
        "updatedAt": self.updatedAt,
        "deletedAt": self.deletedAt,
    ] }
}

extension CKRecord {
    func updateValues<ModelType: CloudKitBacked>(from model: ModelType) {
        self.setValuesForKeys(model.cloudBackedProperties)
    }
}

// TODO: implement other sync methods
// TODO: move error handling and fetching code elsewhere

actor CloudKitClient {
    enum ResponseError: Error {
        case notLoggedIn
        case cloud(CKError)
        case other(Error)
    }
    
    private let cloudDatabase: CKDatabase
    
    init(cloudDatabase: CKDatabase) {
        self.cloudDatabase = cloudDatabase
    }

    func handleRecordChanged<ModelType: CloudKitBacked>(_ localRecord: ModelType) async throws(ResponseError) {
        print("CK handleRecordChanged: \(localRecord.cloudID.recordName)")
        
        let cloudRecord = try await findOrCreateCloudRecord(ModelType.self, id: localRecord.cloudID)
        
        cloudRecord.updateValues(from: localRecord)
        
        try await cloudSave(cloudRecord)
    }
    
    func handleRecordsChanged<ModelType: CloudKitBacked>(_ localRecords: [ModelType]) async {
        print("CK handleRecordsChanged: \(localRecords.map(\.cloudID).map(\.recordName))")
    }
    
    func handleRecordDeleted<ModelType: CloudKitBacked>(_ localRecord: ModelType) async {
        print("CK handleRecordDeleted: \(localRecord.cloudID.recordName)")
    }
    
    // MARK: - cloud fetch methods
    
    private func findOrCreateCloudRecord<ModelType: CloudKitBacked>(
        _ type: ModelType.Type,
        id: CKRecord.ID
    ) async throws(ResponseError) -> CKRecord {
        if let record = try await cloudFetch(id) {
            record
        }
        else {
            CKRecord(recordType: String(describing: type), recordID: id)
        }
        
    }
    
    private func cloudFetch(_ id: CKRecord.ID) async throws(ResponseError) -> CKRecord? {
        do {
            return try await cloudDatabase.record(for: id)
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
