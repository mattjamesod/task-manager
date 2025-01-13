import SwiftUI
import KillerData
import KillerModels

@Observable @MainActor
class NewTaskContainer {
    init(context: Database.Scope?) {
        self.context = context
        self.task = nil
    }
    
    var task: KillerTask?
    var shortCircuit: Bool = false
    
    private let context: Database.Scope?
    private var monitorTask: Task<Void, Never>? = nil
    private var thread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
    
    func waitForUpdate(on database: Database) async {
        thread = await database.subscribe(to: KillerTask.self)
        
        self.monitorTask = Task {
            guard let thread = self.thread else { return }
            for await message in thread.events {
                switch message {
                case .recordChange(_, let id, sender: _):
                    if id == task?.id { push() }
                case .recordsChanged(_, let ids, sender: _):
                    if let id = task?.id, ids.contains(id) { push() }
                default: continue
                }
            }
        }
    }
    
    public func stopMonitoring(database: Database) async {
        guard let thread else { return }
        self.monitorTask?.cancel()
        self.monitorTask = nil
        await database.unsubscribe(thread)
        self.thread = nil
    }
    
    func push(shortCircuit: Bool = false) {
        self.shortCircuit = shortCircuit
        self.task = KillerTask.empty(context: self.context)
    }
    
    func clear() {
        self.task = nil
    }
}
