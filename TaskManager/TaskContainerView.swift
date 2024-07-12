import SwiftUI
import KillerModels
import KillerData
import AsyncAlgorithms

@Observable @MainActor
class TaskContainerViewModel {
    var tasks: [KillerTask] = []
    
    func addOrUpdate(task: KillerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        else {
            tasks.append(task)
        }
    }
    
    func remove(with id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
}

struct TaskContainerView: View {
    @Environment(\.database) var database
    @State var viewModel: TaskContainerViewModel = .init()
    
    let queryMonitor: QueryMonitor<KillerTask>
    
    init(query: Database.Query) {
        self.queryMonitor = .init(of: query)
    }
    
    var body: some View {
        ZStack {
            TaskList {
                ForEach(viewModel.tasks) { task in
                    TaskView(task: task)
                }
            }
            .animation(.bouncy, value: viewModel.tasks)
            
            VStack(spacing: 16) {
                NewTaskButton()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 16)
        }
        .environment(viewModel)
        .task {
            guard let database else { return }
            
            viewModel.tasks = await queryMonitor.fetch(from: database)
            await queryMonitor.listenForTasks(on: database)
        }
        .task {
            for await event in await queryMonitor.syncEvents {
                switch event {
                case .addOrUpdate(let task):
                    viewModel.addOrUpdate(task: task)
                case .remove(let id):
                    viewModel.remove(with: id)
                }
            }
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
    @Environment(TaskContainerViewModel.self) var taskContainerViewModel
    @Environment(\.database) var database
    
    let task: KillerTask
    
    var body: some View {
        HStack {
            Button.async(action: { await database?.update(task, \.completedAt <- Date.now) }) {
                Label("Complete", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            Text(task.body)
            Spacer()
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .contextMenu(menuItems: {
            Button.async(action: { await database?.update(task, \.deletedAt <- Date.now) }) {
                Label("Delete", systemImage: "trash")
            }
            Button.async(action: { await database?.update(task, \.body <- "I've been updated 🎉") }) {
                Label("Update", systemImage: "arrow.right")
            }
        })
    }
}

struct NewTaskButton: View {
    @Environment(TaskContainerViewModel.self) var taskContainerViewModel
    @Environment(\.database) var database
    
    var body: some View {
        Button("Add New Task") {
            Task.detached {
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task")
            }
        }
    }
}

extension Button {
    static func async(
        action: @Sendable @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(action: { Task.detached { await action() }}, label: label)
    }
}
