import SwiftUI
import KillerModels
import KillerData

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

struct TaskWithChildrenView: View {
    @Environment(\.focusedTaskID) var focusedTaskID
    
    @State var newTaskContainer: NewTaskContainer
    
    init(task: KillerTask, context: Database.Scope?) {
        self.task = task
        self.newTaskContainer = .init(context: context?.compose(with: .children(of: task.id)))
    }
    
    let task: KillerTask
    
    var body: some View {
        Group {
            TaskView(task: task)
                .focused(focusedTaskID!, equals: task.id)
            TaskListView(parentID: task.id)
                .padding(.leading, 24)
        }
        .environment(newTaskContainer)
    }
}

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.taskListMonitor) var taskListMonitor
    @Environment(Selection<KillerTask>.self) var selection
        
    @State var taskContainer: TaskContainer
    @State var loadState: TaskContainerState = .loading
    @Environment(NewTaskContainer.self) var newTaskContainer
    
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
        TaskList {
            ForEach(taskContainer.tasks) { task in
                TaskWithChildrenView(task: task, context: contextQuery)
            }
        }
        .animation(.bouncy(duration: 0.4), value: taskContainer.tasks)
        .task {
            await activeMonitor?.register(container: taskContainer)
        }
        .task {
            guard let database else { return }
            
            let tasks = await database.fetch(
                KillerTask.self,
                context: contextQuery?.compose(with: self.detailQuery)
            )
            
            self.taskContainer.tasks = tasks
            
            // onChange will not do anything if an empty array is reassigned to empty array
            if tasks.count == 0 {
                self.loadState = .empty
                newTaskContainer.clear()
            }
            
            await self.newTaskContainer.waitForUpdate(on: database)
        }
        // append or remove a blank task with relevant context when the monitor
        // says to do so
        .onChange(of: newTaskContainer.task) {
            if let task = newTaskContainer.task {
                self.taskContainer.tasks.append(task)
            }
            else {
                if self.taskContainer.tasks.count > 0 {
                    self.taskContainer.tasks.removeLast()
                }
            }
        }
        .onChange(of: taskContainer.tasks) {
            let newTask: Bool = newTaskContainer.task != nil
            let count = newTask ? taskContainer.tasks.count - 1 : taskContainer.tasks.count
            
            if count == 0 {
                self.loadState = .empty
                
                if newTask {
                    guard !newTaskContainer.shortCircuit else {
                        newTaskContainer.shortCircuit = false
                        self.loadState = .done(itemCount: 1)
                        return
                    }
                    
                    self.newTaskContainer.clear()
                }
            }
            else {
                self.loadState = .done(itemCount: count)
                
                if !newTask {
                    self.newTaskContainer.push()
                }
            }
        }
        .taskListState(self.loadState)
        .onDisappear {
            Task {
                await activeMonitor?.deregister(container: taskContainer)
                guard let database else { return }
                await newTaskContainer.stopMonitoring(database: database)
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
