import SwiftUI
import KillerModels
import KillerData

// TODO: Mutating observable property \TaskListViewModel.tasks after view is torn down has no effect.
// Memory leak?

extension RandomAccessCollection {
    /// Finds such index N that predicate is true for all elements up to
    /// but not including the index N, and is false for all elements
    /// starting with index N.
    /// Behavior is undefined if there is no such N.
    func binarySearch(predicate: (Element) -> Bool) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
            if predicate(self[mid]) {
                low = index(after: mid)
            } else {
                high = mid
            }
        }
        return low
    }
}

@Observable @MainActor
class TaskListViewModel: StateContainerizable {
    
    var tasks: [KillerTask]
    let parentID: Int?
    
    init(_ tasks: [KillerTask], parentID: Int?) {
        self.tasks = tasks
        self.parentID = parentID
    }
    
    init(tree: NodeCollection<KillerTask>, parentID: Int?) {
        self.tasks = tree.map(\.object)
        self.parentID = parentID
    }
        
    func addOrUpdate(model: KillerTask) {
        guard model.parentID == self.parentID else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == model.id }) {
            tasks[index] = model
        }
        else {
            tasks.append(model)
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
}

struct TaskContainerView: View {
    @Environment(\.database) var database
    
    @State var initialTasks: NodeCollection<KillerTask>?
    
    let queryMonitor: QueryMonitor<TaskListViewModel>
    
    init(query: Database.Query) {
        self.queryMonitor = .init(of: query)
        self.initialTasks = nil
    }
    
    var body: some View {
        ZStack {
            if let initialTasks {
                TaskListView(taskNodes: initialTasks, parentID: nil, monitor: queryMonitor)
            }
            
            VStack(spacing: 16) {
                NewTaskButton()
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 16)
        }
        .task {
            await setupData()
        }
    }
    
    private func setupData() async {
        guard let database else { return }
        
//        initialTasks = buildTree(from: await database.fetch(KillerTask.self, rootID: 4, context: .allActiveTasks))
        initialTasks = buildTree(from: await queryMonitor.fetch(from: database))
                
        await queryMonitor.beginMonitoring(database)
    }
}

struct TaskListView: View {
    
    @State var viewModel: TaskListViewModel
    var nodes: NodeCollection<KillerTask>
    
    let monitor: QueryMonitor<TaskListViewModel>
    
    init(taskNodes: NodeCollection<KillerTask>, parentID: Int?, monitor: QueryMonitor<TaskListViewModel>) {
        self.nodes = taskNodes
        self.viewModel = TaskListViewModel(tree: taskNodes, parentID: parentID)
        self.monitor = monitor
    }
    
    private func children(of task: KillerTask) -> NodeCollection<KillerTask> {
        self.nodes.first(where: { $0.id == task.id })?.children ?? []
    }
    
    var body: some View {
        TaskList {
            ForEach(viewModel.tasks) { task in
                TaskView(task: task)
                TaskListView(taskNodes: children(of: task), parentID: task.id, monitor: monitor)
                    .padding(.leading, 24)
            }
        }
        .animation(.bouncy, value: viewModel.tasks)
        .task {
            await monitor.keepSynchronised(state: viewModel)
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
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task", \.parentID <- 4)
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
