import KillerModels
import CloudKit
@preconcurrency import SQLite

public actor CloudKitDownloadEngine {
    let typeRegistry: [String: any DataBacked.Type] = [
        "KillerTask": KillerTask.self
    ]
    
    private let client: CloudKitClient
    private let database: Database
    
    public init(cloud: CKDatabase, local: Database) {
        self.client = CloudKitClient(database: cloud)
        self.database = local
    }
    
    public func downloadLatestChanges() async throws {
        var changeToken = try CloudKitChangeToken().fetch()
        var moreComing: Bool = true
        
        while moreComing {
            let changes = try await client.fetchLatestChanges(since: changeToken)
            
            try await handleModifications(changes.modified)
            try await handleDeletions(changes.deleted)
            
            changeToken = changes.newToken
            moreComing = changes.moreComing
        }
        
        try CloudKitChangeToken().save(changeToken)
    }
    
    private func handleModifications(_ modifications: [CKDatabase.RecordZoneChange.Modification]) async throws {
        let partitionedCloudRecords = Dictionary(grouping: modifications.map(\.record), by: \.recordType)
        
        for partition in partitionedCloudRecords {
            guard let modelType = typeRegistry[partition.key] else { continue }
            
            let localRecords = await matchRecords(modelType, partition.value)
            
            for localRecord in localRecords {
                let cloudRecord = localRecord.key
                
                if let localRecord = localRecord.value {
                    await database.update(
                        localRecord,
                        modelType.databaseSetters(from: cloudRecord),
                        sender: .cloudSync
                    )
                }
                else {
                    await database.insert(
                        modelType,
                        modelType.databaseSetters(from: cloudRecord),
                        sender: .cloudSync
                    )
                }
            }
        }
    }
    
    private func handleDeletions(_ deletions: [CKDatabase.RecordZoneChange.Deletion]) async throws {
        let partitions = Dictionary(grouping: deletions, by: \.recordType)
        
        for partition in partitions {
            guard let modelType = typeRegistry[partition.key] else { continue }
            
            await database.deleteByCloudID(
                modelType,
                partition.value.compactMap {
                    UUID(uuidString: $0.recordID.recordName)
                }
            )
        }
    }
    
    /// Queries the local database for records with the same type and ID as a given list of cloud
    /// records. Returns a dictionary mapping those cloud records to a mathcing local record if found, or
    /// nil if not
    private func matchRecords<Model: DataBacked>(
        _ type: Model.Type,
        _ cloudRecords: [CKRecord]
    ) async -> [CKRecord : Model?] {
        let uuids = cloudRecords.compactMap { UUID(uuidString: $0.recordID.recordName) }
        
        let scope = Database.Scope { table in
            table.filter(uuids.contains(SQLite.Expression<UUID>("cloudID")))
        }
        
        let models = await database.fetch(Model.self, context: scope)
        
        return Dictionary(uniqueKeysWithValues: cloudRecords.map { cloudRecord in
            (cloudRecord, models.first(where: { $0.cloudID == cloudRecord.recordID }))
        })
    }
}
