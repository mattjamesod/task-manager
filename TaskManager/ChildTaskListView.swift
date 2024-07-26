import SwiftUI
import KillerModels
import KillerData
import UtilAlgorithms

// TODO: Mutating observable property \ChildTaskListViewModel.tasks after view is torn down has no effect

@Observable @MainActor
final class TaskListViewModel: SynchronisedStateContainer {
    
    var tasks: [KillerTask]
    let filter: (KillerTask) -> Bool
    let sortOrder: (KillerTask, KillerTask) -> Bool
    
    init(
        _ tasks: [KillerTask],
        filter: @escaping (KillerTask) -> Bool = { _ in true },
        sortOrder: @escaping (KillerTask, KillerTask) -> Bool = { $0.createdAt < $1.createdAt }
    ) {
        self.tasks = tasks
        self.filter = filter
        self.sortOrder = sortOrder
    }
        
    func addOrUpdate(model: KillerTask) {
        guard filter(model) else { return }
        
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

struct ChildTaskListView: View {
    @Environment(\.database) var database
    @Environment(\.taskListMonitor) var monitor
    @Environment(\.contextQuery) var query
    
    @State var viewModel: TaskListViewModel
    
    let parentID: Int?
    
    init(parentID: Int?) {
        self.parentID = parentID
        self.viewModel = TaskListViewModel([], filter: { $0.parentID == parentID })
    }
    
    var body: some View {
        TaskList {
            ForEach(viewModel.tasks) { task in
                TaskView(task: task)
                ChildTaskListView(parentID: task.id)
                    .padding(.leading, 24)
            }
        }
        .animation(.bouncy, value: viewModel.tasks)
        .task {
            guard let database else { return }
            viewModel.tasks = await database.fetchChildren(KillerTask.self, id: self.parentID, context: query)
        }
        .task {
            await monitor?.keepSynchronised(state: viewModel)
        }
        .onDisappear {
            Task {
                await monitor?.deregister(state: viewModel)
            }
        }
    }
}

struct TaskListView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    
    @State var viewModel: TaskListViewModel
    
    let monitor: QueryMonitor<TaskListViewModel>
    let detailQuery: Database.Query?
    
    init(_ detailQuery: Database.Query? = nil) {
        self.viewModel = TaskListViewModel([])
        
        self.monitor = .init()
        self.detailQuery = detailQuery
    }
    
    var body: some View {
        TaskList {
            ForEach(viewModel.tasks) { task in
                TaskView(task: task)
                ChildTaskListView(parentID: task.id)
                    .padding(.leading, 24)
            }
        }
        .animation(.bouncy, value: viewModel.tasks)
        .task {
            guard let database else { return }
            
            viewModel.tasks = await database.fetch(KillerTask.self, context: contextQuery?.compose(with: self.detailQuery))
        }
        .task {
            guard let database else { return }
            guard let query = contextQuery?.compose(with: self.detailQuery) else { return }
            
            await monitor.beginMonitoring(query, on: database)
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
