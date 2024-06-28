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
            await database?.update(task, suchThat: \.isCompleted, is: true)
        }
    }
    
    private func deleteButtonAction() {
        guard taskListManager.remove(task: self.task) else { return }
        
        Task.detached {
            await database?.update(task, suchThat: \.isDeleted, is: true)
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
