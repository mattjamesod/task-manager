
public struct KillerTask: Identifiable, Equatable, Clonable {
    public init(id: Int? = nil, body: String, isCompleted: Bool, isDeleted: Bool) {
        self.id = id
        self.body = body
        self.isCompleted = isCompleted
        self.isDeleted = isDeleted
    }
    
    public let id: Int?
    public let body: String
    public var isCompleted: Bool
    public var isDeleted: Bool
}

protocol Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self
}

extension Clonable {
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
}
