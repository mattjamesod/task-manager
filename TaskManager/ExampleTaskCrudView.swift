import SwiftUI
import KillerModels
import KillerData
import AsyncAlgorithms

actor TaskListener {
    func listen(to database: Database, for taskListManager: TaskListManager) async {
        let incomingMessages = await KillerTask.messageHandler.subscribe()
        
        for await event in incomingMessages {
            switch event {
            case .insert(let id):
                guard let task = await taskListManager.fetch(id: id, on: database) else {
                    await taskListManager.remove(with: id)
                    break
                }
                await taskListManager.add(task: task)
            case .update(let id):
                guard let task = await taskListManager.fetch(id: id, on: database) else {
                    await taskListManager.remove(with: id)
                    break
                }
                await taskListManager.update(task: task)
            }
        }
    }
}

@Observable @MainActor
class TaskListManager {
    let taskContext: Database.QueryContext = .allActiveTasks
    
    var tasks: [KillerTask] = []
    
    func add(task: KillerTask) {
        tasks.append(task)
    }
    
    func update(task: KillerTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
    }
    
    func remove(task: KillerTask) -> Bool {
        guard let index = tasks.firstIndex(of: task) else { return false }
        tasks.remove(at: index)
        return true
    }
    
    func remove(with id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
    
    nonisolated func fetch(id: Int, on database: Database) async -> KillerTask? {
        await database.fetch(KillerTask.self, id: id, context: self.taskContext)
    }
    
    nonisolated func fetch(on database: Database) async {
        let tasks = await database.fetch(KillerTask.self, query: self.taskContext)
        Task { @MainActor in
            self.tasks = tasks
        }
    }
}

struct ExampleTaskCrudView: View {
    @Environment(\.database) var database
    @State var taskListManager: TaskListManager = .init()
    var taskListener: TaskListener = .init()
    
    var body: some View {
        ZStack {
            TaskList {
                ForEach(taskListManager.tasks) { task in
                    TaskView(task: task)
                }
            }
            .animation(.bouncy, value: taskListManager.tasks)
            
            VStack(spacing: 16) {
                NewTaskButton()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 16)
        }
        .environment(taskListManager)
        .task {
            guard let database else { return }
            
            await taskListManager.fetch(on: database)
            await taskListener.listen(to: database, for: taskListManager)
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
        Task.detached {
            await database?.update(task, \.completedAt <- Date.now)
        }
    }
    
    private func superDeleteButtonAction() {
        Task.detached {
            await database?.update(task, \.deletedAt <- 45.days.ago)
        }
    }
    
    private func deleteButtonAction() {
        Task.detached {
            await database?.update(task, \.deletedAt <- Date.now)
        }
    }
    
    private func updateBodyAction() {
        Task.detached {
            await database?.update(task, \.body <- "I've been updated 🎉")
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
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task")
            }
        }
    }
}
