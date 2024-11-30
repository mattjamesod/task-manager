import Foundation
import KillerModels
import AsyncAlgorithms
import SQLite
import Logging

public enum DatabaseMessage: Sendable {
    case recordChange(_ type: any SchemaBacked.Type, id: Int)
    case recordsChanged(ids: Set<Int>)
    case recordDeleted(id: Int)
}

public actor AsyncMessageHandler<T: Sendable> {
    public struct Thread: Identifiable, Sendable {
        nonisolated public let id: UUID = .init()
        public var events: AsyncChannel<T>
        
        public init() {
            self.events = .init()
        }
    }
    
    public init() { }
    
    private var messageThreads: [Thread] = []
    
    public func subscribe() -> Thread {
        let newThread = Thread()
        self.messageThreads.append(newThread)
        return newThread
    }
    
    public func unsubscribe(_ thread: Thread) {
        guard let index = self.messageThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        self.messageThreads.remove(at: index)
    }
    
    public func send(_ message: T) async {
        for thread in messageThreads {
            await thread.events.send(message)
        }
    }
}
