import SwiftUI
import UtilAlgorithms
import KillerModels
import KillerData

// TODO: Mutating observable property \TaskListViewModel.tasks after view is torn down has no effect

@Observable @MainActor
final class TaskListViewModel: SynchronisedStateContainer, Identifiable, Sendable {
    
    var tasks: [KillerTask]
    let parentID: Int?
    let sortOrder: (KillerTask, KillerTask) -> Bool
    
    init(
        _ tasks: [KillerTask],
        parentID: Int?,
        sortOrder: @escaping (KillerTask, KillerTask) -> Bool = { $0.createdAt < $1.createdAt }
    ) {
        self.tasks = tasks
        self.parentID = parentID
        self.sortOrder = sortOrder
    }
        
    func addOrUpdate(model: KillerTask) {
        guard model.parentID == self.parentID else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == model.id }) {
            tasks[index] = model
        }
        else {
            tasks.insert(model, at: insertIndex(of: model))
        }
    }
    
    func addOrUpdate(models: [KillerTask]) {
        for model in models {
            addOrUpdate(model: model)
        }
    }
    
    func remove(with id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
    
    func remove(with ids: Set<Int>) {
        for id in ids {
            remove(with: id)
        }
    }
    
    private func insertIndex(of task: KillerTask) -> Int {
        self.tasks.binarySearch { self.sortOrder($0, task) }
    }
}

struct TaskContainerView: View {
    @Environment(\.database) var database
    
    let queryMonitor: QueryMonitor<TaskListViewModel>
    
    init(query: Database.Query) {
        self.queryMonitor = .init(of: query)
    }
    
    var body: some View {
        ZStack {
            TaskListView(parentID: nil, monitor: queryMonitor)
            
            HStack(spacing: 16) {
                NewTaskButton()
                UndoButton()
                RedoButton()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 16)
        }
        .task {
            guard let database else { return }
            await queryMonitor.beginMonitoring(database)
        }
    }
}

struct TaskListView: View {
    @Environment(\.database) var database
    @State var viewModel: TaskListViewModel
    
    let monitor: QueryMonitor<TaskListViewModel>
    
    init(parentID: Int?, monitor: QueryMonitor<TaskListViewModel>) {
        self.viewModel = TaskListViewModel([], parentID: parentID)
        self.monitor = monitor
    }
    
    var body: some View {
        TaskList {
            ForEach(viewModel.tasks) { task in
                TaskView(task: task)
                TaskListView(parentID: task.id, monitor: monitor)
                    .padding(.leading, 24)
            }
        }
        .animation(.bouncy, value: viewModel.tasks)
        .task {
            guard let database else { return }
            viewModel.tasks = await monitor.fetchChildren(from: database, id: viewModel.parentID)
        }
        .task {
            await monitor.keepSynchronised(state: viewModel)
        }
        .onDisappear {
            Task {
                await monitor.deregister(state: viewModel)
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
        .padding(.horizontal, 16)
    }
}

struct TaskView: View {
    @Environment(\.database) var database
        
    let task: KillerTask
    
    var body: some View {
        HStack {
            Button.async(action: { await database?.update(task, \.completedAt <- Date.now) }) {
                Label("Complete", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            Text("\(task.id!): \(task.body)")
            Spacer()
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .contextMenu(menuItems: {
            Button.async(action: { await database?.update(task, recursive: true, \.deletedAt <- Date.now) }) {
                Label("Delete", systemImage: "trash")
            }
            Button.async(action: { await database?.update(task, \.body <- "I've been updated 🎉") }) {
                Label("Update", systemImage: "arrow.right")
            }
        })
    }
}

struct NewTaskButton: View {
    @Environment(\.database) var database
    
    var body: some View {
        Button("Add New Task") {
            Task.detached {
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task")//, \.parentID <- 23)
            }
        }
    }
}

struct UndoButton: View {
    @Environment(\.database) var database
    
    var body: some View {
        Button("Undo") {
            Task.detached {
                await database?.undo()
            }
        }
    }
}

struct RedoButton: View {
    @Environment(\.database) var database
    
    var body: some View {
        Button("Redo") {
            Task.detached {
                await database?.redo()
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
