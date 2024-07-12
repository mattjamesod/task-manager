import SwiftUI
import KillerModels
import KillerData

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
class TaskContainerViewModel {
    
    var tasks: [KillerTask] = []
    
    func addOrUpdate(task: KillerTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
        else {
            tasks.insert(task, at: position(of: task))
        }
    }
    
    func remove(with id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
    
    private func position(of task: KillerTask) -> Int {
        tasks.binarySearch { $0.createdAt < task.createdAt }
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
            await setupData()
        }
        .task {
            await listenForSyncEvents()
        }
    }
    
    private func setupData() async {
        guard let database else { return }
        
        viewModel.tasks = await queryMonitor.fetch(from: database)
        await queryMonitor.beginMonitoring(database)
    }
    
    private func listenForSyncEvents() async {
        for await event in await queryMonitor.syncEvents {
            switch event {
            case .addOrUpdate(let task): viewModel.addOrUpdate(task: task)
            case .remove(let id): viewModel.remove(with: id)
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .long
        return formatter
    }
    
    var body: some View {
        HStack {
            Button.async(action: { await database?.update(task, \.completedAt <- Date.now) }) {
                Label("Complete", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
            }
            Text(dateFormatter.string(from: task.createdAt))
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
