import SwiftUI
import KillerData
import KillerModels

/// Responsible for providing a non-persisted KillerTask to be shown at the bottom of a task list
/// Whenever the user edits this task, it is persisted and the pending task provider serves another
/// new non-persisted task
///
/// Takes on the role of a container and a monitor, but it's probably not worth splitting at this time

@Observable @MainActor
class PendingTaskProvider {
    init(listContext: Database.Scope?) {
        self.context = listContext
        self.task = nil
    }
    
    var task: KillerTask?
    
    private var shortCircuit: Bool = false
    private let context: Database.Scope?
    private var monitorTask: Task<Void, Never>? = nil
    private var thread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
    
    func respondToChanges(on database: Database) async {
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
    
    /// When the number of tasks in the list changes, we might want to start or stop
    /// providing the task
    func onListChange(itemCount: Int) {
        if itemCount > 0 && task == nil {
            self.push()
        }
        else if itemCount == 1 && task != nil {
            // sometimes we want to add a pending task as the only task in the list
            guard !shortCircuit else { shortCircuit = false; return }
            self.clear()
        }
    }
    
    func push(shortCircuit: Bool = false) {
        guard context?.allowsTaskEntry ?? false else { return }
        
        self.shortCircuit = shortCircuit
        self.task = KillerTask.empty(context: self.context)
    }
    
    func clear() {
        self.task = nil
    }
}

extension KillerTask {
    static func empty(context: Database.Scope? = nil) -> KillerTask {
        let base = KillerTask(
            id: UUID(),
            body: "",
            createdAt: nil,
            updatedAt: nil
        )
        
        if let context {
            return context.applyToModel(base)
        }
        else {
            return base
        }
    }
}
