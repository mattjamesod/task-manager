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
    
    let monitor: QueryMonitor<TaskProvider>?
    let detailQuery: Database.Scope?
    
    init(_ detailQuery: Database.Scope? = nil, monitor: QueryMonitor<TaskProvider>) {
        self.taskProvider = TaskProvider(isOrphan: true)
        self.monitor = monitor
        self.detailQuery = detailQuery
    }
    
    init(parentID: Int?) {
        self.taskProvider = TaskProvider(filter: { $0.parentID == parentID }, isOrphan: false)
        self.monitor = nil
        self.detailQuery = .children(of: parentID)
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
            guard let database else { return }
            
            taskProvider.tasks = await database.fetch(
                KillerTask.self,
                context: contextQuery?.compose(with: self.detailQuery)
            )
        }
        .task {
            let provider = taskProvider
            print("\(taskProvider.isOrphan) - \(self.monitor != nil)")
            await activeMonitor?.register(container: provider)
        }
        .onDisappear {
            Task {
                let provider = taskProvider
                await activeMonitor?.deregister(container: provider)
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
