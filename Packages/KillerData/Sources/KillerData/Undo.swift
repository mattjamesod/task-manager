//
//actor MutationHistory<StateActorType> {
//    var operations: [Bijection<StateActorType>]
//    var undoLevel: Int = 0
//    
//    func record(_ operation: Bijection<StateActorType>) {
//        if undoLevel > 0 {
//            operations.dropLast(undoLevel)
//            undoLevel = 0
//        }
//    }
//    
//    func undo(_ stateActor: StateActorType) {
//        undoLevel += 1
//    }
//    
//    func redo(_ stateActor: StateActorType) {
//        undoLevel -= 1
//    }
//}
//
//struct Bijection<StateActorType>: Sendable {
//    let forward: @Sendable (StateActorType) -> Void
//    let backward: @Sendable (StateActorType) -> Void
//}
