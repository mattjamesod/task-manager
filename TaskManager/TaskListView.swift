import SwiftUI
import KillerModels
import KillerData

extension KillerTask {
    static func empty() -> KillerTask {
        KillerTask(
            id: UUID(),
            body: "",
            createdAt: nil,
            updatedAt: nil
        )
    }
}

@Observable @MainActor
class NewTaskMonitor {
    var task: KillerTask = KillerTask.empty()
    
    private var thread: AsyncMessageHandler<DatabaseMessage>.Thread? = nil
    
    func waitForUpdate(on database: Database) async {
        thread = await database.subscribe(to: KillerTask.self)
        
        for await message in thread!.events {
            switch message {
            case .recordChange(_, let id, sender: _):
                if id == task.id { task = KillerTask.empty() }
            case .recordsChanged(_, let ids, sender: _):
                if ids.contains(task.id) { task = KillerTask.empty() }
            default: continue
            }
        }
    }
}

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.taskListMonitor) var taskListMonitor
    @Environment(\.focusedTaskID) var focusedTaskID
    @Environment(Selection<KillerTask>.self) var selection
        
    @State var taskProvider: TaskProvider
    @State var loadState: TaskContainerState = .loading
    @State var newTaskMonitor: NewTaskMonitor = .init()
    
    let monitor: QueryMonitor<TaskProvider>?
    let detailQuery: Database.Scope?
    
    let includeNewTask: Bool
    
    init(_ detailQuery: Database.Scope? = nil, monitor: QueryMonitor<TaskProvider>) {
        self.taskProvider = TaskProvider()
        self.monitor = monitor
        self.detailQuery = detailQuery
        self.includeNewTask = true
    }
    
    init(parentID: UUID?) {
        self.taskProvider = TaskProvider(filter: { $0.parentID == parentID })
        self.monitor = nil
        self.detailQuery = .children(of: parentID)
        self.includeNewTask = false
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
            
            if includeNewTask {
                self.taskProvider.tasks = tasks + [self.newTaskMonitor.task]
            }
            else {
                self.taskProvider.tasks = tasks
            }
            
            // onChange will not do anything if an empty array is reassigned to empty array
            if self.taskProvider.tasks.count == 0 {
                self.loadState = .empty
            }
            
            await self.newTaskMonitor.waitForUpdate(on: database)
        }
        .onChange(of: newTaskMonitor.task) {
            self.taskProvider.tasks.append(newTaskMonitor.task)
        }
        .onChange(of: taskProvider.tasks) {
            let count = taskProvider.tasks.count
            self.loadState = count == 0 ? .empty : .done(itemCount: count)
        }
        .taskListState(self.loadState)
        .onDisappear {
            Task {
                await activeMonitor?.deregister(container: taskProvider)
            }
        }
    }
    
    private var activeMonitor: QueryMonitor<TaskProvider>? {
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
