import KillerModels

public protocol RecursiveData: Identifiable where ID == Int? {
    var parentID: Int? { get }
}

extension KillerTask: RecursiveData { }

public typealias NodeCollection<T: RecursiveData> = [Node<T>]

public func buildTree<Element>(from values: [Element]) -> NodeCollection<Element> {
    let nodes = values.map(Node.init)
    let groups = Dictionary(grouping: nodes, by: \.parentID)
    
    groups.forEach { pair in
        guard pair.key != nil else { return }
        
        let parent = nodes.first { $0.id == pair.key }
        parent?.children = pair.value
    }
    
    return groups[nil] ?? []
}

public class Node<ObjectType: RecursiveData> {
    public let object: ObjectType
    public let id: ObjectType.ID
    public let parentID: ObjectType.ID
    
    public var children: NodeCollection<ObjectType> = .init()
    
    init(_ object: ObjectType) {
        self.object = object
        self.id = object.id
        self.parentID = object.parentID
    }
}
