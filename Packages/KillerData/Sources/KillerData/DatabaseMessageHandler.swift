import Foundation
import KillerModels
import AsyncAlgorithms
import SQLite

public enum DatabaseMessage: Sendable {
    case recordChange(id: Int)
    case recordsChanged(ids: Set<Int>)
    case recordDeleted(id: Int)
}

extension DatabaseMessage {
    public struct Thread: Identifiable, Sendable {
        public var id: UUID = .init()
        public var events: AsyncChannel<DatabaseMessage>
        
        public init() {
            self.events = .init()
        }
    }
}

public protocol DatabaseMessageHandler: Actor {
    typealias MessageThread = AsyncChannel<DatabaseMessage>
    func subscribe() -> DatabaseMessage.Thread
    func unsubscribe(_ thread: DatabaseMessage.Thread)
    func send(_ message: DatabaseMessage) async
}

public actor KillerTaskMessageHandler: DatabaseMessageHandler {
    static public var instance: KillerTaskMessageHandler = .init()
    private var messageThreads: [DatabaseMessage.Thread] = []
    
    private init() { }
    
    public func subscribe() -> DatabaseMessage.Thread {
        let newThread = DatabaseMessage.Thread()
        self.messageThreads.append(newThread)
        return newThread
    }
    
    public func unsubscribe(_ thread: DatabaseMessage.Thread) {
        guard let index = self.messageThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        self.messageThreads.remove(at: index)
    }
    
    public func send(_ message: DatabaseMessage) async {
        for thread in messageThreads {
            await thread.events.send(message)
        }
    }
}
