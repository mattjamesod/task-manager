import CloudKit

actor CloudKitClient {
    enum ResponseError: Error {
        case notLoggedIn
        case cloud(CKError)
        case other(Error)
        
        static func wrapping(_ error: Error) -> ResponseError {
            guard let cloudError = error as? CKError else {
                return .other(error)
            }
            
            if cloudError.code == .accountTemporarilyUnavailable {
                // the user is not logged in to an iCloud account. We should have caught this
                // earlier, but if we didn't, the caller knows what to do
                return .notLoggedIn
            }
            
            return .cloud(cloudError)
        }
    }
    
    private let database: CKDatabase
    
    init(database: CKDatabase) {
        self.database = database
    }
    
    func findOrCreateRecord<ModelType: CloudKitBacked>(
        _ type: ModelType.Type,
        id: CKRecord.ID
    ) async throws(ResponseError) -> CKRecord {
        if let record = try await fetch(id) {
            record
        }
        else {
            CKRecord(recordType: String(describing: type), recordID: id)
        }
    }
    
    func findOrCreateRecords<ModelType: CloudKitBacked>(
        for localRecords: [ModelType]
    ) async throws(ResponseError) -> [CloudKitUpdateRecordPair<ModelType>] {
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
    
    func fetch(_ id: CKRecord.ID) async throws(ResponseError) -> CKRecord? {
        do {
            return try await database.record(for: id)
        }
        catch {
            if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                return nil
            }
            
            throw ResponseError.wrapping(error)
        }
    }
    
    private func fetch(ids: [CKRecord.ID]) async throws(ResponseError) -> [CKRecord.ID : CKRecord] {
        do {
            return try await database.records(for: ids)
                .compactMapValues { result in
                    do {
                        return try result.get() as CKRecord?
                    }
                    catch {
                        if let cloudError = error as? CKError, cloudError.code == .unknownItem {
                            return nil
                        }
                        
                        throw ResponseError.wrapping(error)
                    }
                }
        }
        catch {
            throw ResponseError.wrapping(error)
        }
    }
    
    func save(_ record: CKRecord) async throws(ResponseError) {
        do {
            try await database.save(record)
        }
        catch {
            throw ResponseError.wrapping(error)
        }
    }
    
    func save(_ records: [CKRecord]) async throws(ResponseError) {
        do {
            try await database.modifyRecords(saving: records, deleting: [])
        }
        catch {
            throw ResponseError.wrapping(error)
        }
    }
    
    func delete(_ id: CKRecord.ID) async throws(ResponseError) {
        do {
            try await database.deleteRecord(withID: id)
        }
        catch {
            throw ResponseError.wrapping(error)
        }
    }
}
