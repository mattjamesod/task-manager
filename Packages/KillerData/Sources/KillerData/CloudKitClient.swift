import Foundation
import KillerModels
import CloudKit
import Logging

class CloudKitUpdateRecordPair<LocalRecord: CloudKitBacked>: Identifiable {
    let id: CKRecord.ID
    let localRecord: LocalRecord
    let cloudRecord: CKRecord
    
    init(id: CKRecord.ID, localRecord: LocalRecord, cloudRecord: CKRecord?) {
        self.id = id
        self.localRecord = localRecord
        self.cloudRecord = cloudRecord ?? CKRecord(recordType: String(describing: LocalRecord.self), recordID: id)
    }
    
    func updateCloudValues() {
        self.cloudRecord.updateValues(from: self.localRecord)
    }
}

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

actor CloudKitClient: CustomConsoleLogger {
    let logToConsole: Bool = true
    
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
        log("CK handleRecordChanged: \(localRecord.cloudID.recordName)")
        
        let cloudRecord = try await findOrCreateCloudRecord(ModelType.self, id: localRecord.cloudID)
        
        cloudRecord.updateValues(from: localRecord)
        
        try await cloudSave(cloudRecord)
    }
    
    func handleRecordsChanged<ModelType: CloudKitBacked>(_ localRecords: [ModelType]) async throws(ResponseError) {
        log("CK handleRecordsChanged: \(localRecords.map(\.cloudID).map(\.recordName))")
        
        let recordPairs = try await findOrCreateCloudRecords(for: localRecords)
        
        recordPairs.forEach { $0.updateCloudValues() }
        
        try await cloudSave(recordPairs.map(\.cloudRecord))
    }
    
    func handleRecordDeleted<ModelType: CloudKitBacked>(_ localRecord: ModelType) async throws(ResponseError) {
        log("CK handleRecordDeleted: \(localRecord.cloudID.recordName)")
        
        // TODO: does this throw if record not exists?
        try await cloudDelete(localRecord.cloudID)
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
    
    private func findOrCreateCloudRecords<ModelType: CloudKitBacked>(
        for localRecords: [ModelType]
    ) async throws(ResponseError) -> [CloudKitUpdateRecordPair<ModelType>] {
        do {
            let fetchResults = try await cloudDatabase.records(for: localRecords.map(\.cloudID))
            let indexedRecords = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.cloudID, $0) })
            
            let cloudRecords = try fetchResults.compactMapValues { result in
                do {
                    return try result.get() as CKRecord?
                }
                catch {
                    if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                        return nil
                    }
                    
                    throw asResponseError(error)
                }
            }
            
            return indexedRecords.map { kvp in
                CloudKitUpdateRecordPair(
                    id: kvp.key,
                    localRecord: kvp.value,
                    cloudRecord: cloudRecords[kvp.key]
                )
            }
        }
        catch {
            throw asResponseError(error)
        }
    }
    
    private func cloudFetch(_ id: CKRecord.ID) async throws(ResponseError) -> CKRecord? {
        do {
            return try await cloudDatabase.record(for: id)
        }
        catch {
            if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                return nil
            }
            
            throw asResponseError(error)
        }
    }
    
    private func cloudSave(_ record: CKRecord) async throws(ResponseError) {
        do {
            try await cloudDatabase.save(record)
        }
        catch {
            throw asResponseError(error)
        }
    }
    
    private func cloudSave(_ records: [CKRecord]) async throws(ResponseError) {
        do {
            try await cloudDatabase.modifyRecords(saving: records, deleting: [])
        }
        catch {
            throw asResponseError(error)
        }
    }
    
    private func cloudDelete(_ id: CKRecord.ID) async throws(ResponseError) {
        do {
            try await cloudDatabase.deleteRecord(withID: id)
        }
        catch {
            throw asResponseError(error)
        }
    }
    
    private func asResponseError(_ error: Error) -> ResponseError {
        guard let cloudError = error as? CKError else {
            return ResponseError.other(error)
        }
        
        if cloudError.code == .accountTemporarilyUnavailable {
            // the user is not logged in to an iCloud account. We should have caught this
            // earlier, but if we didn't, the caller knows what to do
            return ResponseError.notLoggedIn
        }
        
        return ResponseError.cloud(cloudError)
    }
}
