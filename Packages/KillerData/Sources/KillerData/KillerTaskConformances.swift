import KillerModels
import CloudKit
@preconcurrency import SQLite

extension KillerTask: SchemaBacked {
    public typealias Schema = Database.Schema.Tasks
    
    public static func create(from databaseRecord: SQLite.Row) throws -> KillerTask {
        do {
            return KillerTask(
                id: try databaseRecord.get(Database.Schema.Tasks.id),
                body: try databaseRecord.get(Database.Schema.Tasks.body),
                createdAt: try databaseRecord.get(Database.Schema.Tasks.createdAt),
                updatedAt: try databaseRecord.get(Database.Schema.Tasks.updatedAt),
                completedAt: try databaseRecord.get(Database.Schema.Tasks.completedAt),
                deletedAt: try databaseRecord.get(Database.Schema.Tasks.deletedAt),
                parentID: try databaseRecord.get(Database.Schema.Tasks.parentID)
            )
        }
        catch {
            // TODO: log property error
            throw DatabaseError.propertyDoesNotExist
        }
    }
    
    public static func getSchemaExpression<T>(
        for keyPath: KeyPath<Self, T>
    ) throws -> SQLite.Expression<T> where T: SQLite.Value {
        switch keyPath {
        case \.id: Schema.id as! SQLite.Expression<T>
        case \.body: Schema.body as! SQLite.Expression<T>
        case \.createdAt: Schema.createdAt as! SQLite.Expression<T>
        case \.updatedAt: Schema.updatedAt as! SQLite.Expression<T>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
    
    public static func getSchemaExpression<T>(
        optional keyPath: KeyPath<Self, T?>
    ) throws -> SQLite.Expression<T?> where T: SQLite.Value {
        switch keyPath {
        case \.completedAt: Schema.completedAt as! SQLite.Expression<T?>
        case \.deletedAt: Schema.deletedAt as! SQLite.Expression<T?>
        case \.parentID: Schema.parentID as! SQLite.Expression<T?>
        default: throw DatabaseError.propertyDoesNotExist
        }
    }
    
    static public func creationProperties() -> [Setter] { [
        Schema.id <- UUID(),
        Schema.createdAt <- Date.now,
        Schema.updatedAt <- Date.now,
    ] }
    
    public func duplicationProperties() -> [Setter] { [
        Schema.body <- self.body,
        Schema.completedAt <- self.completedAt,
        Schema.deletedAt <- self.deletedAt,
        Schema.parentID <- self.parentID,
    ] }
}

extension KillerTask: CloudKitBacked {
    public var cloudID: CKRecord.ID {
        CKRecord.ID(recordName: self.id.uuidString, zoneID: CloudKitZone.userData.id)
    }
    
    public var cloudBackedProperties: [String : Any] { [
        "body": self.body,
        "completedAt": self.completedAt,
        "parentID": self.parentID,
        "createdAt": self.createdAt,
        "updatedAt": self.updatedAt,
        "deletedAt": self.deletedAt,
    ] }
}

extension KillerTask: DataBacked {
    // TODO: encode these defaults and key names somewhere sensible
    public static func databaseSetters(from cloudRecord: CKRecord) -> [Setter] { [
        KillerTask.Schema.id <- UUID(uuidString: cloudRecord.recordID.recordName)!,
        KillerTask.Schema.body <- cloudRecord.value(forKey: "body") as? String ?? "",
        KillerTask.Schema.completedAt <- cloudRecord.value(forKey: "completedAt") as? Date,
        KillerTask.Schema.parentID <- UUID(uuidString: cloudRecord.value(forKey: "parentID") as! String),
        KillerTask.Schema.createdAt <- cloudRecord.value(forKey: "createdAt") as? Date ?? Date.now,
        KillerTask.Schema.updatedAt <- cloudRecord.value(forKey: "updatedAt") as? Date ?? Date.now,
        KillerTask.Schema.deletedAt <- cloudRecord.value(forKey: "deletedAt") as? Date,
    ] }
}
