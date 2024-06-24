import SwiftUI

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
    let database = Database(schema: .userData)
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
        .environment(\.database, database)
        .task {
            do {
                try await database.connect()
            }
            catch {
                
            }
            taskListManager.tasks = await database.fetchTasks()
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
            await database?.update(task: task, suchThat: \.isCompleted, is: true)
        }
    }
    
    private func deleteButtonAction() {
        guard taskListManager.remove(task: self.task) else { return }
        
        Task.detached {
            await database?.update(task: task, suchThat: \.isDeleted, is: true)
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
                if let newTask = await database?.newTask() {
                    await taskListManager.add(task: newTask)
                }
            }
        }
    }
}
