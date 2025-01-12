import SwiftUI
import KillerModels
import KillerData

extension KillerTask {
    static func empty(_ parentID: UUID?) -> KillerTask {
        KillerTask(
            id: UUID(),
            body: "",
            createdAt: nil,
            updatedAt: nil,
            parentID: parentID
        )
    }
}

@Observable @MainActor
class NewTaskMonitor {
    init(parentID: UUID?) {
        self.parentID = parentID
        self.task = nil
    }
    
    var task: KillerTask?
    
    private let parentID: UUID?
    private var monitorTask: Task<Void, Never>? = nil
    private var thread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
    
    func waitForUpdate(on database: Database) async {
        thread = await database.subscribe(to: KillerTask.self)
        
        self.monitorTask = Task {
            guard let thread = self.thread else { return }
            for await message in thread.events {
                switch message {
                case .recordChange(_, let id, sender: _):
                    if id == task?.id { update() }
                case .recordsChanged(_, let ids, sender: _):
                    if let id = task?.id, ids.contains(id) { update() }
                default: continue
                }
            }
        }
    }
    
    public func stop(database: Database) async {
        guard let thread else { return }
        self.monitorTask?.cancel()
        self.monitorTask = nil
        await database.unsubscribe(thread)
        self.thread = nil
    }
    
    func update(empty: Bool = false) {
        if empty {
            self.task = nil
        }
        else {
            self.task = KillerTask.empty(parentID)
        }
    }
}

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.taskListMonitor) var taskListMonitor
    @Environment(\.focusedTaskID) var focusedTaskID
    @Environment(Selection<KillerTask>.self) var selection
        
    @State var taskProvider: TaskContainer
    @State var loadState: TaskContainerState = .loading
    @State var newTaskMonitor: NewTaskMonitor
    
    @State var shortCircuit: Bool = false
    
    let monitor: QueryMonitor<TaskContainer>?
    let detailQuery: Database.Scope?
    
    init(_ detailQuery: Database.Scope? = nil, monitor: QueryMonitor<TaskContainer>) {
        self.taskProvider = TaskContainer()
        self.monitor = monitor
        self.detailQuery = detailQuery
        
        self._newTaskMonitor = State(initialValue: .init(parentID: nil))
    }
    
    init(parentID: UUID?) {
        self.taskProvider = TaskContainer(filter: { $0.parentID == parentID })
        self.monitor = nil
        self.detailQuery = .children(of: parentID)
        
        self._newTaskMonitor = State(initialValue: .init(parentID: parentID))
    }
    
    var body: some View {
        TaskList {
            ForEach(taskProvider.tasks) { task in
                TaskView(task: task)
                    .focused(focusedTaskID!, equals: task.id)
                TaskListView(parentID: task.id)
                    .padding(.leading, 24)
            }
        }
        .animation(.bouncy(duration: 0.4), value: taskProvider.tasks)
        .task {
            await activeMonitor?.register(container: taskProvider)
        }
        .task {
            guard let database else { return }
            
            let tasks = await database.fetch(
                KillerTask.self,
                context: contextQuery?.compose(with: self.detailQuery)
            )
            
            self.taskProvider.tasks = tasks
            
            // onChange will not do anything if an empty array is reassigned to empty array
            if tasks.count == 0 {
                self.loadState = .empty
                newTaskMonitor.update(empty: true)
            }
            
            await self.newTaskMonitor.waitForUpdate(on: database)
        }
        // append or remove a blank task with relevant context when the monitor
        // says to do so
        .onChange(of: newTaskMonitor.task) {
            shortCircuit = true
            
            if let task = newTaskMonitor.task {
                self.taskProvider.tasks.append(task)
            }
            else {
                if self.taskProvider.tasks.count > 0 {
                    self.taskProvider.tasks.removeLast()
                }
            }
        }
        .onChange(of: taskProvider.tasks) {
            guard !shortCircuit else { shortCircuit = false; return }
            
            let count = taskProvider.tasks.count
            let newTask: Bool = newTaskMonitor.task != nil
            
            if count == 0  || (newTask && count == 1) {
                self.loadState = .empty
                self.newTaskMonitor.update(empty: true)
            }
            else {
                self.loadState = .done(itemCount: count)
                if newTaskMonitor.task == nil {
                    newTaskMonitor.update(empty: false)
                }
            }
        }
        .taskListState(self.loadState)
        .onDisappear {
            Task {
                await activeMonitor?.deregister(container: taskProvider)
                guard let database else { return }
                await newTaskMonitor.stop(database: database)
            }
        }
    }
    
    private var activeMonitor: QueryMonitor<TaskContainer>? {
        self.monitor ?? taskListMonitor
    }
}

struct TaskList<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(subviews: content) { subView in
                subView
            }
        }
    }
}
