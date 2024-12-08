import Foundation
import CloudKit

typealias RecordZoneChangesResponse = (
    modificationResultsByID: [CKRecord.ID : Result<CKDatabase.RecordZoneChange.Modification, any Error>],
    deletions: [CKDatabase.RecordZoneChange.Deletion],
    changeToken: CKServerChangeToken,
    moreComing: Bool
)

struct CloudKitChanges {
    let modified: [CKDatabase.RecordZoneChange.Modification]
    let deleted: [CKDatabase.RecordZoneChange.Deletion]
    let moreComing: Bool
    let newToken: CKServerChangeToken
    
    init(
        _ modified: [CKDatabase.RecordZoneChange.Modification],
        _ deleted: [CKDatabase.RecordZoneChange.Deletion],
        _ newToken: CKServerChangeToken,
        _ moreComing: Bool
    ) {
        self.modified = modified
        self.deleted = deleted
        self.newToken = newToken
        self.moreComing = moreComing
    }
}

actor CloudKitClient {
    static let containerName: String = "iCloud.com.missingapostrophe.scopes"
    
    struct RecordPair<LocalRecord: CloudKitBacked>: Identifiable, Sendable {
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
    
    
    private let database: CKDatabase
    
//    init(database: CKDatabase) {
//        self.database = database
//    }
    
    init() {
        self.database = CKContainer(identifier: Self.containerName).privateCloudDatabase
    }
    
    func ensureZoneExists(_ zone: CloudKitZone) async throws(CloudKitResponseError) {
        guard !zone.alreadySetup else { return }
        
        // check in cloud DB that zone has not been setup by another client
        let foundZone: CKRecordZone?
        
        do {
            foundZone = try await database.recordZone(for: zone.id)
        }
        catch {
            try CloudKitResponseError.ignoreMissingZone(error)
            foundZone = nil
        }
        
        guard foundZone == nil else {
            zone.registerSetup()
            return
        }
        
        try await save(CKRecordZone(zoneID: zone.id))
        
        zone.registerSetup()
    }
    
    func ensureSubscriptionExists() async throws(CloudKitResponseError) {
        guard !CloudKitSubscription.alreadySetup else { return }
        
        // check in cloud DB that subscription has not been setup by another client
        let foundSubscription: CKSubscription?
        
        do {
            foundSubscription = try await database.subscription(for: CloudKitSubscription.id)
        }
        catch {
            try CloudKitResponseError.ignoreUnknownItem(error)
            foundSubscription = nil
        }
        
        guard foundSubscription == nil else {
            CloudKitSubscription.registerSetup()
            return
        }
        
        try await save(CloudKitSubscription.build())
        
        CloudKitSubscription.registerSetup()
    }
    
    func fetchLatestChanges(since changeToken: CKServerChangeToken?) async throws(CloudKitResponseError) -> CloudKitChanges {
        let changes: RecordZoneChangesResponse
        
        do {
            changes = try await database.recordZoneChanges(
                inZoneWith: CloudKitZone.userData.id,
                since: changeToken
            )
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
        
        let modifications = try changes.modificationResultsByID.values.compactMap { change in
            do {
                return try change.get()
            }
            catch {
                // TODO: log this somewhere for yourself, user maybe?
                return nil
            }
        }
        
        return CloudKitChanges(modifications, changes.deletions, changes.changeToken, changes.moreComing)
    }
    
    func findOrCreateRecord<Model: CloudKitBacked>(
        _ type: Model.Type,
        id: CKRecord.ID
    ) async throws(CloudKitResponseError) -> CKRecord {
        if let record = try await fetch(id) {
            record
        }
        else {
            CKRecord(recordType: String(describing: type), recordID: id)
        }
    }
    
    func findOrCreateRecords<Model: CloudKitBacked>(
        for localRecords: [Model]
    ) async throws(CloudKitResponseError) -> [RecordPair<Model>] {
        let cloudRecords = try await fetch(ids: localRecords.map(\.cloudID))
        let indexedLocalRecords = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.cloudID, $0) })
        
        return indexedLocalRecords.map { kvp in
            RecordPair(
                id: kvp.key,
                localRecord: kvp.value,
                cloudRecord: cloudRecords[kvp.key]
            )
        }
    }
    
    func fetch(_ id: CKRecord.ID) async throws(CloudKitResponseError) -> CKRecord? {
        do {
            return try await database.record(for: id)
        }
        catch {
            try CloudKitResponseError.ignoreUnknownItem(error)
            return nil
        }
    }
    
    private func fetch(ids: [CKRecord.ID]) async throws(CloudKitResponseError) -> [CKRecord.ID : CKRecord] {
        do {
            return try await database.records(for: ids)
                .compactMapValues { result in
                    do {
                        return try result.get() as CKRecord?
                    }
                    catch {
                        try CloudKitResponseError.ignoreUnknownItem(error)
                        return nil
                    }
                }
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func save(_ record: CKRecord) async throws(CloudKitResponseError) {
        do {
            try await database.save(record)
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func save(_ zone: CKRecordZone) async throws(CloudKitResponseError) {
        do {
            try await database.save(zone)
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func save(_ subscription: CKSubscription) async throws(CloudKitResponseError) {
        do {
            try await database.modifySubscriptions(saving: [subscription], deleting: [])
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func save(_ records: [CKRecord]) async throws(CloudKitResponseError) {
        do {
            try await database.modifyRecords(saving: records, deleting: [])
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func delete(_ id: CKRecord.ID) async throws(CloudKitResponseError) {
        do {
            try await database.deleteRecord(withID: id)
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
    
    func delete(_ ids: [CKRecord.ID]) async throws(CloudKitResponseError) {
        do {
            try await database.modifyRecords(saving: [], deleting: ids)
        }
        catch {
            throw CloudKitResponseError.wrapping(error)
        }
    }
}
