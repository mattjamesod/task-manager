import KillerModels
import CloudKit

public actor CloudKitDownloadEngine {
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
        let groupedByType = Dictionary(grouping: modifications.map(\.record), by: \.recordType)
        
        groupedByType.forEach { keyValuePair in
            let typeString = keyValuePair.key
            
            let type: Any.Type = switch typeString {
            case "KillerTask": KillerTask.self
            default: Int.self
            }
            
            
        }
    }
    
    private func handleDeletions(_ modifications: [CKDatabase.RecordZoneChange.Deletion]) async throws {
        
    }
}
