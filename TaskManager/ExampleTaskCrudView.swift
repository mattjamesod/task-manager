import SwiftUI
import KillerModels
import KillerData

@Observable @MainActor 
class TaskListManager {
    var tasks: [KillerTask] = []
    
    func add(task: KillerTask) {
        tasks.append(task)
    }
    
    func remove(task: KillerTask) -> Bool {
        guard let index = tasks.firstIndex(of: task) else { return false }
        tasks.remove(at: index)
        return true
    }
    
    func update<T>(task: KillerTask, suchThat path: WritableKeyPath<KillerTask, T>, is value: T) -> Bool {
        guard let index = tasks.firstIndex(of: task) else { return false }
        tasks[index][keyPath: path] = value
        return true
    }
}

struct ExampleTaskCrudView: View {
    @Environment(\.database) var database
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
            taskListManager.tasks = await database?.fetch(KillerTask.self, query: .allActiveItems) ?? []
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
    @Environment(\.database) var database
    let task: KillerTask
    
    private func completeButtonAction() {
        guard taskListManager.remove(task: self.task) else { return }
        
        Task.detached {
            await database?.update(task, suchThat: \.completedAt, is: Date.now)
        }
    }
    
    private func deleteButtonAction() {
        guard taskListManager.remove(task: self.task) else { return }
        
        Task.detached {
            await database?.update(task, suchThat: \.deletedAt, is: Date.now)
        }
    }
    
    private func updateBodyAction() {
        let newBody = "I've been updated 🎉"
        
        guard taskListManager.update(task: self.task, suchThat: \.body, is: newBody) else { return }
        
        Task.detached {
            await database?.update(task, suchThat: \.body, is: newBody)
        }
    }
    
    var body: some View {
        HStack {
            Button(action: completeButtonAction) {
                Label("Complete", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            Text(task.body)
            Spacer()
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .contextMenu(menuItems: {
            Button(action: deleteButtonAction) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: updateBodyAction) {
                Label("Update", systemImage: "square.and.pencil")
            }
        })
    }
}

struct NewTaskButton: View {
    @Environment(TaskListManager.self) var taskListManager
    @Environment(\.database) var database
    
    var body: some View {
        Button("Add New Task") {
            Task.detached {
                if let newTask = await database?.insert(KillerTask.self, setting: \.body, to: "A brand new baby task!") {
                    await taskListManager.add(task: newTask)
                }
            }
        }
    }
}
