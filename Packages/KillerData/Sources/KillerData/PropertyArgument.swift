import SQLite

infix operator <-

public func <-<ModelType: SchemaBacked, T: SQLite.Value>(keyPath: WritableKeyPath<ModelType, T>, value: T) -> PropertyArgument<ModelType, T> {
    PropertyArgument(keyPath, value)
}

public func <-<ModelType: SchemaBacked, T: SQLite.Value>(keyPath: WritableKeyPath<ModelType, T?>, value: T) -> PropertyArgument<ModelType, T> {
    PropertyArgument(keyPath, value)
}

// Sendable conformance must be unchecked because we wnat to use this type in parameter packs, and as of writing,
// parameter packs themselves complain about concurrency even if their underlying types are sendable, UNLESS it is
// @unchecked...
public struct PropertyArgument<ModelType: SchemaBacked, T: SQLite.Value>: @unchecked Sendable {
    public init(_ keyPath: WritableKeyPath<ModelType, T>, _ value: T) {
        self._keyPath = keyPath
        self._value = value
        self._optionalKeyPath = nil
    }
    
    public init(_ keyPath: WritableKeyPath<ModelType, T?>, _ value: T?) {
        self._optionalKeyPath = keyPath
        self._value = value
        self._keyPath = nil
    }
    
    private let _keyPath: WritableKeyPath<ModelType, T>?
    private let _optionalKeyPath: WritableKeyPath<ModelType, T?>?
    private let _value: T?
    
    func getSetter() throws -> Setter {
        if let _keyPath {
            try ModelType.getSchemaExpression(for: _keyPath) <- _value!
        }
        else if let _optionalKeyPath {
            try ModelType.getSchemaExpression(optional: _optionalKeyPath) <- _value
        }
        else {
            // one of the above properties must exist, so this code is impossible to reach
            fatalError()
        }
    }
    
//    func writeValue(to model: inout ModelType) {
//        if let _keyPath {
//            model[keyPath: _keyPath] = _value!
//        }
//        else if let _optionalKeyPath {
//            model[keyPath: _optionalKeyPath] = _value
//        }
//        else {
//            // one of the above properties must exist, so this code is impossible to reach
//            fatalError()
//        }
//    }
}
