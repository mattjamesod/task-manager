import CloudKit
@preconcurrency import SQLite

public protocol DataBacked: SchemaBacked & CloudKitBacked {
    static func databaseSetters(from cloudRecord: CKRecord) -> [Setter]
}

// MARK: - SchemaBacked

public protocol SchemaBacked: Sendable {
    associatedtype Schema: TableSchema
    
    static func create(from databaseRecord: SQLite.Row) throws -> Self
    static func getSchemaExpression<T>(for keyPath: KeyPath<Self, T>) throws -> SQLite.Expression<T> where T: SQLite.Value
    static func getSchemaExpression<T>(optional keyPath: KeyPath<Self, T?>) throws -> SQLite.Expression<T?> where T: SQLite.Value
    
    static func creationProperties() -> [Setter]
    func duplicationProperties() -> [Setter]
    
    var id: Int { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
    var deletedAt: Date? { get }
}

// MARK: - CloudKitBacked

public protocol CloudKitBacked: Sendable {
    var cloudID: CKRecord.ID { get }
    var cloudBackedProperties: [String : Any] { get }
}

struct AnyCloudKitBacked: CloudKitBacked {
    private let wrapped: any CloudKitBacked
    
    init(_ wrapped: any CloudKitBacked) {
        self.wrapped = wrapped
    }
    
    var cloudID: CKRecord.ID { wrapped.cloudID }
    var cloudBackedProperties: [String : Any] { wrapped.cloudBackedProperties }
}

extension CKRecord {
    func updateValues<ModelType: CloudKitBacked>(from model: ModelType) {
        self.setValuesForKeys(model.cloudBackedProperties)
    }
}
