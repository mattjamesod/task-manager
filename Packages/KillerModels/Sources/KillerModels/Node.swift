import KillerModels

public protocol RecursiveData: Identifiable where ID == Int? {
    var parentID: Int? { get }
}

public extension RecursiveData {
    static func buildTrees<Self>(list: [Self]) -> [Node<Self>] {
        let nodes = list.map(Node.init)
        let groups = Dictionary(grouping: nodes, by: \.parentID)
        
        groups.forEach { pair in
            guard pair.key != nil else { return }
            
            let parent = nodes.first { $0.id == pair.key }
            parent?.children = pair.value
        }
        
        return groups[nil] ?? []
    }
}

extension KillerTask: RecursiveData { }

public final class Node<ObjectType: RecursiveData>: Sendable {
    public let object: ObjectType
    public let id: ObjectType.ID
    public let parentID: ObjectType.ID
    
    public var children: [Node<ObjectType>] = .init()
    
    init(_ object: ObjectType) {
        self.object = object
        self.id = object.id
        self.parentID = object.parentID
    }
}
