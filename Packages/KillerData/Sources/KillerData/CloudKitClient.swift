import CloudKit

actor CloudKitClient {
    private let database: CKDatabase
    
    init(database: CKDatabase) {
        self.database = database
    }
    
    func findOrCreateRecord<ModelType: CloudKitBacked>(
        _ type: ModelType.Type,
        id: CKRecord.ID
    ) async throws(CloudKitResponseError) -> CKRecord {
        if let record = try await fetch(id) {
            record
        }
        else {
            CKRecord(recordType: String(describing: type), recordID: id)
        }
    }
    
    func findOrCreateRecords<ModelType: CloudKitBacked>(
        for localRecords: [ModelType]
    ) async throws(CloudKitResponseError) -> [CloudKitUpdateRecordPair<ModelType>] {
        let cloudRecords = try await fetch(ids: localRecords.map(\.cloudID))
        let indexedLocalRecords = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.cloudID, $0) })
        
        return indexedLocalRecords.map { kvp in
            CloudKitUpdateRecordPair(
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
}
