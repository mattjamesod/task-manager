import SwiftUI

public actor MutationHistory {
    var operations: [Bijection] = []
    var undoLevel: Int = 0
    
    public init(operations: [Bijection] = [], undoLevel: Int = 0) {
        self.operations = operations
        self.undoLevel = undoLevel
    }
    
    public func record(_ operation: Bijection) {
        if undoLevel > 0 {
            operations = operations.dropLast(undoLevel)
            undoLevel = 0
        }
        
        operations.append(operation)
    }
    
    public func undo() async {
        guard undoLevel < operations.count else { return }
        
        let operation = operations[operations.count - 1 - undoLevel]
        
        await operation.goBackward()
        
        undoLevel += 1
    }
    
    public func redo() async {
        guard undoLevel > 0 else { return }
        let operation = operations[operations.count - undoLevel]
        
        await operation.goForward()
        
        undoLevel -= 1
    }
}

public struct Bijection: Sendable {
    public init(
        goForward: @escaping @Sendable () async -> Void,
        goBackward: @escaping @Sendable () async -> Void
    ) {
        self.goForward = goForward
        self.goBackward = goBackward
    }
    
    public let goForward: @Sendable () async -> Void
    public let goBackward: @Sendable () async -> Void
}
