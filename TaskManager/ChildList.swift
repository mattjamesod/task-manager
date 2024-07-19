import KillerModels

protocol RecursiveData: Identifiable where ID == Int? {
    var parentID: Int? { get }
    var children: [Self] { get set }
}

extension KillerTask: RecursiveData { }

struct ChildList<T: RecursiveData & Equatable & Identifiable> {
    var chains: Dictionary<Int?, [T]>
    
    init(values: [T]) {
        self.chains = Dictionary(grouping: values, by: \.parentID)
    }
    
    var iteratorValues: [Int?] {
        Array(self.chains.keys)
    }
}

typealias NodeCollection<T: RecursiveData> = [Node<T>]

func buildTree<Element>(from values: [Element]) -> NodeCollection<Element> {
    let nodes = values.map(Node.init)
    let groups = Dictionary(grouping: nodes, by: \.parentID)
    
    groups.forEach { pair in
        guard pair.key != nil else { return }
        
        let parent = nodes.first { $0.id == pair.key }
        parent?.children = pair.value
    }
    
    return groups[nil] ?? []
}

class Node<ObjectType: RecursiveData> {
    
    let object: ObjectType
    let id: ObjectType.ID
    let parentID: ObjectType.ID
    
    var children: NodeCollection<ObjectType> = .init()
    
    init(_ object: ObjectType) {
        self.object = object
        self.id = object.id
        self.parentID = object.parentID
    }
}
