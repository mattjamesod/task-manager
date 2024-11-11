import SwiftUI
import Logging

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

public enum MutationHistoryMessage: Sendable {
    case canUndo(Bool)
    case canRedo(Bool)
}

public extension EnvironmentValues {
    @Entry var canUndo: Bool = false
    @Entry var canRedo: Bool = false
}

public actor MutationHistory: CustomConsoleLogger {
    public nonisolated let logToConsole: Bool = false
    
    public static let messageHandler: AsyncMessageHandler<MutationHistoryMessage> = .init()
    
    var operations: [Bijection] = []
    var undoLevel: Int = 0
    
    public init(operations: [Bijection] = [], undoLevel: Int = 0) {
        self.operations = operations
        self.undoLevel = undoLevel
    }
    
    public func record(_ operation: Bijection) {
        if undoLevel > 0 {
            log("recoridng operation while inside undo stack; \(undoLevel) operations lost")
            operations = operations.dropLast(undoLevel)
            undoLevel = 0
        }
        
        operations.append(operation)
        
        alertListenersToState()
        
        log("recorded operation; \(operations.count) in history")
    }
    
    public func undo() async {
        guard undoLevel < operations.count else {
            log("ignoring undo request: all recorded operations have been undone")
            return
        }
        
        let operation = operations[operations.count - 1 - undoLevel]
        
        await operation.goBackward()
        
        undoLevel += 1
        
        alertListenersToState()
        
        log("operation undone; undo level is \(undoLevel)")
    }
    
    public func redo() async {
        guard undoLevel > 0 else {
            log("ignoring redo request: nothing to redo")
            return
        }
        
        let operation = operations[operations.count - undoLevel]
        
        await operation.goForward()
        
        undoLevel -= 1
        
        alertListenersToState()
        
        log("operation redone; undo level is \(undoLevel)")
    }
    
    private func alertListenersToState() {
        Task {
            await MutationHistory.messageHandler.send(.canUndo(self.canUndo))
            await MutationHistory.messageHandler.send(.canRedo(self.canRedo))
        }
    }
    
    private var canUndo: Bool {
        undoLevel < operations.count
    }
    
    private var canRedo: Bool {
        self.undoLevel > 0
    }
}
