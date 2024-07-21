import KillerModels
import AsyncAlgorithms
import SQLite

public enum DatabaseMessage: Sendable {
    case recordChange(id: Int)
    case recordsChanged(ids: Set<Int>)
    case recordDeleted(id: Int)
}

public protocol DatabaseMessageHandler: Actor {
    typealias MessageThread = AsyncChannel<DatabaseMessage>
    func subscribe() -> MessageThread
    func send(_ message: DatabaseMessage) async
}

public actor KillerTaskMessageHandler: DatabaseMessageHandler {
    static public var instance: KillerTaskMessageHandler = .init()
    private var messageThreads: [MessageThread] = []
    
    private init() { }
    
    public func subscribe() -> MessageThread {
        let newThread = MessageThread()
        self.messageThreads.append(newThread)
        return newThread
    }
    
    public func send(_ message: DatabaseMessage) async {
        for thread in messageThreads {
            await thread.send(message)
        }
    }
}
