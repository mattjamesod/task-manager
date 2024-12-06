import SQLite

infix operator <-

public func <-<Model: SchemaBacked, T: SQLite.Value>(keyPath: WritableKeyPath<Model, T>, value: T) -> PropertyArgument<Model, T> {
    PropertyArgument(keyPath, value)
}

public func <-<Model: SchemaBacked, T: SQLite.Value>(keyPath: WritableKeyPath<Model, T?>, value: T?) -> PropertyArgument<Model, T> {
    PropertyArgument(keyPath, value)
}

// Sendable conformance must be unchecked because we want to use this type in parameter packs, and as of writing,
// parameter packs themselves complain about concurrency even if their underlying types are sendable, UNLESS it is
// @unchecked...
public struct PropertyArgument<Model: SchemaBacked, T: SQLite.Value>: @unchecked Sendable {
    public init(_ keyPath: WritableKeyPath<Model, T>, _ value: T) {
        self._keyPath = keyPath
        self._value = value
        self._optionalKeyPath = nil
    }
    
    public init(_ keyPath: WritableKeyPath<Model, T?>, _ value: T?) {
        self._optionalKeyPath = keyPath
        self._value = value
        self._keyPath = nil
    }
    
    private let _keyPath: WritableKeyPath<Model, T>?
    private let _optionalKeyPath: WritableKeyPath<Model, T?>?
    private let _value: T?
    
    func getSetter() throws -> Setter {
        if let _keyPath {
            try Model.getSchemaExpression(for: _keyPath) <- _value!
        }
        else if let _optionalKeyPath {
            try Model.getSchemaExpression(optional: _optionalKeyPath) <- _value
        }
        else {
            // one of the above properties must exist, so this code is impossible to reach
            fatalError()
        }
    }
    
    func getInverseSetter(model: Model) throws -> Setter {
        if let _keyPath {
            try Model.getSchemaExpression(for: _keyPath) <- model[keyPath: _keyPath]
        }
        else if let _optionalKeyPath {
            try Model.getSchemaExpression(optional: _optionalKeyPath) <- model[keyPath: _optionalKeyPath]
        }
        else {
            // one of the above properties must exist, so this code is impossible to reach
            fatalError()
        }
    }
}
