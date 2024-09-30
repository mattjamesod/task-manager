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
    
    nonisolated public var logToConsole: Bool { true }
    
    private var messageThreads: [Thread] = []
    
    public func subscribe() -> Thread {
        let newThread = Thread()
        self.messageThreads.append(newThread)
        self.log("New task subscription, total: \(self.messageThreads.count)")
        return newThread
    }
    
    public func unsubscribe(_ thread: Thread) {
        guard let index = self.messageThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        self.messageThreads.remove(at: index)
        self.log("Removed task subscription, total: \(self.messageThreads.count)")
    }
    
    public func send(_ message: T) async {
        self.log("Sending DB message about tasks to \(self.messageThreads.count) listeners: \(message)")
        for thread in messageThreads {
            await thread.events.send(message)
        }
    }
}
