import Foundation
import KillerModels
import AsyncAlgorithms
import SQLite
import Logging

public enum DatabaseMessage: Sendable {
    case recordChange(id: Int)
    case recordsChanged(ids: Set<Int>)
    case recordDeleted(id: Int)
}

public actor AsyncMessageHandler<T: Sendable>: CustomConsoleLogger {
    public struct Thread: Identifiable, Sendable {
        nonisolated public let id: UUID = .init()
        public var events: AsyncChannel<T>
        
        public init() {
            self.events = .init()
        }
    }
    
    // TODO: make this logging useful when this class has many use cases
    nonisolated public let logToConsole: Bool = false
    
    private var messageThreads: [Thread] = []
    
    public func subscribe() -> Thread {
        let newThread = Thread()
        self.messageThreads.append(newThread)
        self.log("New subscription, total: \(self.messageThreads.count)")
        return newThread
    }
    
    public func unsubscribe(_ thread: Thread) {
        guard let index = self.messageThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        self.messageThreads.remove(at: index)
        self.log("Removed subscription, total: \(self.messageThreads.count)")
    }
    
    public func send(_ message: T) async {
        self.log("Sending message to \(self.messageThreads.count) listeners: \(message)")
        for thread in messageThreads {
            await thread.events.send(message)
        }
    }
}
