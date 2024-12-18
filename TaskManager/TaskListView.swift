import SwiftUI
import KillerModels
import KillerData

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
            
            self.taskProvider.tasks = await database.fetch(
                KillerTask.self,
                context: contextQuery?.compose(with: self.detailQuery)
            )
            
            if includeNewTask {
                let newTask = KillerTask(
                    id: newTaskMonitor.currentID,
                    body: "",
                    createdAt: Date.now,
                    updatedAt: Date.now
                )
                
                self.taskProvider.tasks.append(newTask)
            }
            
            // onChange will not do anything if an empty array is reassigned to empty array
            if self.taskProvider.tasks.count == 0 {
                self.loadState = .empty
            }
            
            await self.newTaskMonitor.waitForUpdate(on: database)
        }
        .onChange(of: taskProvider.tasks) {
            let count = taskProvider.tasks.count
            self.loadState = count == 0 ? .empty : .done(itemCount: count)
        }
        .onChange(of: newTaskMonitor.currentID) {
            let newTask = KillerTask(
                id: newTaskMonitor.currentID,
                body: "",
                createdAt: Date.now,
                updatedAt: Date.now
            )
            
            self.taskProvider.tasks.append(newTask)
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
