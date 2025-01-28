import SwiftUI
import KillerModels
import KillerData

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.taskListMonitor) var taskListMonitor
        
    @State var taskContainer: TaskContainer
    @State var loadState: TaskContainerState = .loading
    @Environment(PendingTaskProvider.self) var pendingTaskProvider
    
    let monitor: QueryMonitor<TaskContainer>?
    let detailQuery: Database.Scope?
    
    init(_ detailQuery: Database.Scope? = nil, monitor: QueryMonitor<TaskContainer>) {
        self.taskContainer = TaskContainer()
        self.monitor = monitor
        self.detailQuery = detailQuery
    }
    
    init(parentID: UUID?) {
        self.taskContainer = TaskContainer(filter: { $0.parentID == parentID })
        self.monitor = nil
        self.detailQuery = .children(of: parentID)
    }
    
    var body: some View {
        TaskSpacing {
            ForEach(taskContainer.tasks, id: \.id) { task in
                TaskWithChildrenView(task: task, context: contextQuery)
                    .tasksPending(task.id == pendingTaskProvider.task?.id)
            }
        }
        .animation(.bouncy(duration: 0.4), value: taskContainer.tasks)
        .task {
            await self.load()
        }
        .onDisappear {
            Task {
                await self.unload()
            }
        }
        .onChange(of: pendingTaskProvider.task) {
            self.taskContainer.appendOrRemovePendingTask(pendingTaskProvider.task)
        }
        .onChange(of: taskContainer.tasks) {
            let count = taskContainer.tasks.count
            self.pendingTaskProvider.onListChange(itemCount: count)
        }
        .onChange(of: taskContainer.tasks) {
            let count = taskContainer.tasks.count
            
            if count == 0 {
                self.loadState = .empty
            }
            else {
                self.loadState = .done(itemCount: count)
            }
        }
        .taskListState(self.loadState)
    }
    
    private func load() async {
        await activeMonitor?.register(container: taskContainer)
        
        guard let database else { return }
        
//        try? await Task.sleep(for: .seconds(0.1))
        
        let tasks = await database.fetch(
            KillerTask.self,
            context: contextQuery?.compose(with: self.detailQuery)
        )
        
        self.taskContainer.tasks = tasks
        
        // onChange will not do anything if an empty array is reassigned to empty array
        if tasks.count == 0 {
            self.loadState = .empty
            pendingTaskProvider.clear()
        }
        
        await self.pendingTaskProvider.respondToChanges(on: database)
    }
    
    private func unload() async {
//        self.taskContainer.tasks = []
        self.pendingTaskProvider.clear()
        
        Task {
            await activeMonitor?.deregister(container: taskContainer)
            guard let database else { return }
            await pendingTaskProvider.stopMonitoring(database: database)
        }
    }
    
    private var activeMonitor: QueryMonitor<TaskContainer>? {
        self.monitor ?? taskListMonitor
    }
}

struct TaskSpacing<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(subviews: content) { subView in
                subView
            }
        }
    }
}
