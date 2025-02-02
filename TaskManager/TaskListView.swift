import SwiftUI
import KillerModels
import KillerData

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
        
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
    
    init(parentID: UUID?, monitor: QueryMonitor<TaskContainer>?) {
        self.taskContainer = TaskContainer(filter: { $0.parentID == parentID })
        self.monitor = monitor
        self.detailQuery = .children(of: parentID)
    }
    
    var body: some View {
        TaskSpacing {
            ForEach(taskContainer.tasks, id: \.id) { task in
                TaskView(task: task)
                    .withChildren(of: task, context: contextQuery)
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
        self.loadState = .loading
        await self.monitor?.register(container: taskContainer)
        
        guard let database else { return }
        
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
        self.taskContainer.tasks = []
        self.pendingTaskProvider.clear()
        
        Task {
            await self.monitor?.deregister(container: taskContainer)
            guard let database else { return }
            await pendingTaskProvider.stopMonitoring(database: database)
        }
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
