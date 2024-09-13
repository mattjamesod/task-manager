

public protocol Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self
    func cloned<each T>(suchThat properties: repeat WritableKeyPath<Self, each T>, are value: repeat each T) -> Self
}

public extension Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
    
    func cloned<each T>(suchThat properties: repeat WritableKeyPath<Self, each T>, are values: repeat each T) -> Self {
        var clone = self
        for (property, value) in repeat (each properties, each values) {
            clone[keyPath: property] = value
        }
        return clone
    }
}
