import SwiftUI
import KillerModels
import KillerData

@Observable @MainActor
final class TaskContainerViewModel: SynchronisedStateContainer {
    
    var orphanedParentIDs: [Int?] = [nil]
    
    func addOrUpdate(model: KillerTask) {}
    func addOrUpdate(models: [KillerTask]) {}
    func remove(with id: Int) {}
    func remove(with ids: Set<Int>) {}
}

struct TaskContainerView: View {
    @Environment(\.database) var database
    
    // should care abt the associated type, not the contaienr type
    let queryMonitor: QueryMonitor<TaskListViewModel>
    
    init(query: Database.Query) {
        self.queryMonitor = .init(of: query)
    }
    
    var body: some View {
        ZStack {
            TaskListView(parentID: nil)
                .environment(\.taskListMonitor, queryMonitor)
            
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

extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskListViewModel>? = nil
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
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task")//, \.parentID <- 55)
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
