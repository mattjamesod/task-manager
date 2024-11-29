import Foundation
import KillerModels
import CloudKit
import Logging
@preconcurrency import SQLite

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
    public var cloudID: CKRecord.ID {
        CKRecord.ID(recordName: self.internalCloudID.uuidString, zoneID: CloudKitZone.userData.id)
    }
    
    var cloudBackedProperties: [String : Any] { [
        "body": self.body,
        "completedAt": self.completedAt,
        "parentID": self.parentID,
        "createdAt": self.createdAt,
        "updatedAt": self.updatedAt,
        "deletedAt": self.deletedAt,
    ] }
    
    // TODO: encode these defaults and key names somewhere sensible
    // KillerTask.MetaData.defaultCreatedAt a sensible API?
    static func databaseSetters(from cloudRecord: CKRecord) -> [Setter] { [
        KillerTask.SchemaType.cloudID <- UUID(uuidString: cloudRecord.recordID.recordName)!,
        KillerTask.SchemaType.body <- cloudRecord.value(forKey: "body") as? String ?? "",
        KillerTask.SchemaType.completedAt <- cloudRecord.value(forKey: "completedAt") as? Date,
        KillerTask.SchemaType.parentID <- cloudRecord.value(forKey: "parentID") as? Int,
        KillerTask.SchemaType.createdAt <- cloudRecord.value(forKey: "createdAt") as? Date ?? Date.now,
        KillerTask.SchemaType.updatedAt <- cloudRecord.value(forKey: "updatedAt") as? Date ?? Date.now,
        KillerTask.SchemaType.deletedAt <- cloudRecord.value(forKey: "deletedAt") as? Date,
    ] }
}

extension CKRecord {
    func updateValues<ModelType: CloudKitBacked>(from model: ModelType) {
        self.setValuesForKeys(model.cloudBackedProperties)
    }
}


/// Updates the state of athe remote DB from the local DB, given a list of Models with IDs which are new  / changed

actor CloudKitUploadEngine: CustomConsoleLogger {
    let logToConsole: Bool = true
    
    private let client: CloudKitClient
    
    init(client: CloudKitClient) {
        self.client = client
    }
    
    func ensureRemoteSchemaSetup() async throws(CloudKitResponseError) {
        try await client.ensureZoneExists(.userData)
        try await client.ensureSubscriptionExists()
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
