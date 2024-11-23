import Foundation
import KillerModels
import CloudKit
import Logging

struct CloudKitUpdateRecordPair<LocalRecord: CloudKitBacked>: Identifiable, Sendable {
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

protocol CloudKitBacked: Sendable {
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

actor CloudKitSyncEngine: CustomConsoleLogger {
    let logToConsole: Bool = true
    
    private let client: CloudKitClient
    
    init(client: CloudKitClient) {
        self.client = client
    }

    func handleRecordChanged<ModelType: CloudKitBacked>(
        _ localRecord: ModelType
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordChanged: \(localRecord.cloudID.recordName)")
        
        let cloudRecord = try await client.findOrCreateRecord(ModelType.self, id: localRecord.cloudID)
        
        cloudRecord.updateValues(from: localRecord)
        
        try await client.save(cloudRecord)
    }
    
    func handleRecordsChanged<ModelType: CloudKitBacked>(
        _ localRecords: [ModelType]
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordsChanged: \(localRecords.map(\.cloudID).map(\.recordName))")
        
        let recordPairs = try await client.findOrCreateRecords(for: localRecords)
        
        recordPairs.forEach { $0.updateCloudValues() }
        
        try await client.save(recordPairs.map(\.cloudRecord))
    }
    
    func handleRecordDeleted<ModelType: CloudKitBacked>(
        _ localRecord: ModelType
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordDeleted: \(localRecord.cloudID.recordName)")
        
        // TODO: does this throw if record not exists?
        try await client.delete(localRecord.cloudID)
    }
}
