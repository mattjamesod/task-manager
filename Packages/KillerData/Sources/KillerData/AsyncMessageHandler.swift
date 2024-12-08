import Foundation
import AsyncAlgorithms

public actor AsyncMessageHandler<T: Sendable> {
    public struct Thread: Identifiable, Sendable {
        nonisolated public let id: UUID = .init()
        public var events: AsyncChannel<T>
        
        private var predicate: (@Sendable (T) -> Bool)?
        
        public init(_ predicate: (@Sendable (T) -> Bool)?) {
            self.events = .init()
            self.predicate = predicate
        }
        
        func send(_ message: T) async {
            guard predicate?(message) ?? true else { return }
            await events.send(message)
        }
    }
    
    public init() { }
    
    private var messageThreads: [Thread] = []
    
    public func subscribe(predicate: (@Sendable (T) -> Bool)? = nil) -> Thread {
        let newThread = Thread(predicate)
        self.messageThreads.append(newThread)
        return newThread
    }
    
    public func unsubscribe(_ thread: Thread) {
        guard let index = self.messageThreads.firstIndex(where: { $0.id == thread.id }) else { return }
        self.messageThreads.remove(at: index)
    }
    
    public func send(_ message: T) async {
        for thread in messageThreads {
            await thread.send(message)
        }
    }
}
