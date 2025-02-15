import Foundation
import KillerModels
import CloudKit
import Logging

/// Updates the state of athe remote DB from the local DB, given a list of Models with IDs which are new  / changed

actor CloudKitUploadEngine: CustomConsoleLogger {
    let logToConsole: Bool = false
    
    private let client: CloudKitClient = .init()
    
    func ensureRemoteSchemaSetup() async throws(CloudKitResponseError) {
        try await client.ensureZoneExists(.userData)
        try await client.ensureSubscriptionExists()
    }

    func handleRecordChanged<Model: CloudKitBacked>(
        _ localRecord: Model
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordChanged: \(localRecord.cloudID.recordName)")
        
        let cloudRecord = try await client.findOrCreateRecord(Model.self, id: localRecord.cloudID)
        
        cloudRecord.updateValues(from: localRecord)
        
        try await client.save(cloudRecord)
    }
    
    func handleRecordsChanged<Model: CloudKitBacked>(
        _ localRecords: [Model]
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordsChanged: \(localRecords.map(\.cloudID).map(\.recordName))")
        
        let recordPairs = try await client.findOrCreateRecords(for: localRecords)
        
        recordPairs.forEach { $0.updateCloudValues() }
        
        try await client.save(recordPairs.map(\.cloudRecord))
    }
    
    func handleRecordDeleted(
        _ id: CKRecord.ID
    ) async throws(CloudKitResponseError) {
        log("CK handleRecordDeleted: \(id.recordName)")
        
        // TODO: does this throw if record not exists?
        try await client.delete(id)
    }
    
    func handleRecordsDeleted(
        _ ids: [CKRecord.ID]
    ) async throws(CloudKitResponseError) {
        // TODO: does this throw if record not exists?
        try await client.delete(ids)
    }
}
