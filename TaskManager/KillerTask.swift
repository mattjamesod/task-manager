

struct KillerTask: Identifiable, Equatable {
    let id: Int
    let body: String
    var isCompleted: Bool = false
    var isDeleted: Bool = false
    
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
}
