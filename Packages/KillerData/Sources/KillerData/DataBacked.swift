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
    
    func allProperties() -> [Setter]
    static func creationProperties() -> [Setter]
    func duplicationProperties() -> [Setter]
    
    var id: UUID { get }
    var createdAt: Date? { get }
    var updatedAt: Date? { get }
    var deletedAt: Date? { get }
}

struct AnySchemaBacked: SchemaBacked {
    static func create(from databaseRecord: SQLite.Row) throws -> AnySchemaBacked {
        <#code#>
    }
    
    static func getSchemaExpression<T>(for keyPath: KeyPath<AnySchemaBacked, T>) throws -> SQLite.Expression<T> where T : SQLite.Value {
        <#code#>
    }
    
    static func getSchemaExpression<T>(optional keyPath: KeyPath<AnySchemaBacked, T?>) throws -> SQLite.Expression<T?> where T : SQLite.Value {
        <#code#>
    }
    
    func allProperties() -> [SQLite.Setter] {
        <#code#>
    }
    
    static func creationProperties() -> [SQLite.Setter] {
        wrapped. .creationProperties()
    }
    
    func duplicationProperties() -> [SQLite.Setter] {
        wrapped.duplicationProperties()
    }
    
    var id: UUID { wrapped.id }
    var createdAt: Date? { wrapped.createdAt }
    var updatedAt: Date? { wrapped.updatedAt }
    var deletedAt: Date? { wrapped.deletedAt }
    
    private let wrapped: any SchemaBacked
    
    init(_ wrapped: any SchemaBacked) {
        self.wrapped = wrapped
    }
    
    
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
