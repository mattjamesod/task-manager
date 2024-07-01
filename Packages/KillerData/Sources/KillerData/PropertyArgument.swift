import SQLite

infix operator <-

public func <-<ModelType: SchemaBacked, T: SQLite.Value>(keyPath: KeyPath<ModelType, T>, value: T) -> PropertyArgument<ModelType, T> {
    PropertyArgument(keyPath, value)
}

public func <-<ModelType: SchemaBacked, T: SQLite.Value>(keyPath: KeyPath<ModelType, T?>, value: T) -> PropertyArgument<ModelType, T> {
    PropertyArgument(keyPath, value)
}

public struct PropertyArgument<ModelType: SchemaBacked, T: SQLite.Value> {
    let keyPath: KeyPath<ModelType, T>?
    let optionalKeyPath: KeyPath<ModelType, T?>?
    let value: T?
    
    fileprivate init(_ keyPath: KeyPath<ModelType, T>, _ value: T) {
        self.keyPath = keyPath
        self.value = value
        
        self.optionalKeyPath = nil
    }
    
    fileprivate init(_ keyPath: KeyPath<ModelType, T?>, _ value: T?) {
        self.optionalKeyPath = keyPath
        self.value = value
        
        self.keyPath = nil
    }
    
    func getSetter() throws -> Setter {
        if let keyPath {
            try ModelType.getSchemaExpression(for: keyPath) <- value!
        }
        else if let optionalKeyPath {
            try ModelType.getSchemaExpression(optional: optionalKeyPath) <- value
        }
        else {
            // one of the above properties must exist, so this code is impossible to reach
            fatalError()
        }
    }
}
