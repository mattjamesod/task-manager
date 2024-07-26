import SwiftUI
import KillerModels
import KillerData

struct TaskContainerView: View {
    @Environment(\.database) var database
        
    let taskListMonitor: QueryMonitor<TaskListViewModel> = .init()
    let orphanMonitor: QueryMonitor<TaskListViewModel> = .init()
    
    let query: Database.Query
    
    init(query: Database.Query) {
        self.query = query
    }
    
    var body: some View {
        ZStack {
            TaskListView(.orphaned, monitor: orphanMonitor)
                .environment(\.contextQuery, self.query)
                .environment(\.taskListMonitor, self.taskListMonitor)
            
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
            await taskListMonitor.beginMonitoring(query, on: database)
        }
        .task {
            guard let database else { return }
            await orphanMonitor.beginMonitoring(query.compose(with: .orphaned), on: database)
        }
    }
}

extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskListViewModel>? = nil
    @Entry var contextQuery: Database.Query? = nil
}

struct TaskView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
        
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
            Button.async(action: {
                let query = await self.contextQuery
                await database?.update(task, recursive: true, context: query, \.deletedAt <- Date.now)
            }) {
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
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task")//, \.parentID <- 2)
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
