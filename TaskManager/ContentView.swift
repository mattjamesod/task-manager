import SwiftUI

actor TaskAccessor {
    func fetchTasks() -> [KillerTask] {
        taskDatabase
    }
    
    func newTask() -> KillerTask {
        let newTask = KillerTask(id: newId(), body: "I am a brand new baby task")
        taskDatabase.append(newTask)
        return newTask
    }
    
    func update<T>(task: KillerTask, suchThat path: WritableKeyPath<KillerTask, T>, is value: T) {
        guard let index = taskDatabase.firstIndex(where: { $0.id == task.id }) else { return }
        taskDatabase[index] = taskDatabase[index].cloned(suchThat: path, is: value)
    }
    
    private func newId() -> Int {
        taskDatabase.count + 1
    }
    
    private var taskDatabase: [KillerTask] = [
        KillerTask(id: 1, body: "Take out the trash"),
        KillerTask(id: 2, body: "Buy milk"),
        KillerTask(id: 3, body: "Work on important project")
    ]
}

@Observable @MainActor 
class TaskListManager {
    let taskAccessor: TaskAccessor = .init()
    var tasks: [KillerTask] = []
    
    func addNewTask() async {
        let newTask = await taskAccessor.newTask()
        
        Task { @MainActor in
            tasks.append(newTask)
        }
    }
    
    func complete(task: KillerTask) {
        guard remove(task: task) else { return }
        
        Task.detached { [self] in
            await self.taskAccessor.update(task: task, suchThat: \.isCompleted, is: true)
        }
    }
    
    func delete(task: KillerTask) {
        guard remove(task: task) else { return }
        
        Task.detached { [self] in
            await self.taskAccessor.update(task: task, suchThat: \.isDeleted, is: true)
        }
    }
    
    private func remove(task: KillerTask) -> Bool {
        guard let index = tasks.firstIndex(of: task) else { return false }
        tasks.remove(at: index)
        return true
    }
}

struct ContentView: View {
    @State var taskListManager: TaskListManager = .init()
    
    var body: some View {
        ZStack {
            TaskList {
                ForEach(taskListManager.tasks) { task in
                    TaskView(task: task)
                }
            }
            .animation(.bouncy, value: taskListManager.tasks)
            
            NewTaskButton()
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
        }
        .environment(taskListManager)
        .task {
            taskListManager.tasks = await taskListManager.taskAccessor.fetchTasks()
        }
    }
}

struct TaskList<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(subviewOf: content) { subView in
                subView
            }
        }
        .padding(16)
    }
}

struct TaskView: View {
    @Environment(TaskListManager.self) var taskListManager
    let task: KillerTask
    
    var body: some View {
        HStack {
            Button {
                taskListManager.complete(task: self.task)
            } label: {
                Label("Complete", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            Text(task.body)
            Spacer()
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .contextMenu(menuItems: {
            Button("Delete") {
                taskListManager.delete(task: task)
            }
        })
    }
}

struct NewTaskButton: View {
    @Environment(TaskListManager.self) var taskListManager
    
    var body: some View {
        Button("Add New Task") {
            Task.detached {
                await taskListManager.addNewTask()
            }
        }
    }
}

struct KillerTask: Identifiable, Equatable {
    let id: Int
    let body: String
    var isCompleted: Bool = false
    var isDeleted: Bool = false
    
    func cloned<T>(suchThat path: WritableKeyPath<Self, T>, is value: T) -> Self {
        var clone = self
        clone[keyPath: path] = value
        return clone
    }
}
