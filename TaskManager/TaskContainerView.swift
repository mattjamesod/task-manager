import SwiftUI
import UtilViews
import AsyncAlgorithms
import KillerModels
import KillerData

@Observable @MainActor
final class Selection<T: Identifiable> {
    private(set) var ids: [T.ID] = []
    
    var focused: T.ID? {
        ids.count == 1 ? ids.first! : nil
    }
    
    var last: T.ID? {
        ids.last
    }
    
    func focus(_ obj: T) {
        focus(obj.id)
    }
    
    func focus(_ id: T.ID?) {
        if id == nil {
            ids.removeAll()
        }
        else if let index = ids.firstIndex(of: id!) {
            ids.remove(at: index)
        }
        else {
            ids.removeAll()
            ids.append(id!)
        }
    }
    
    func remove(_ obj: T) {
        if let index = ids.firstIndex(of: obj.id) {
            ids.remove(at: index)
        }
    }
}

struct TaskContainerView: View {
    @Environment(\.database) var database
    @FocusState var focusedTaskID: KillerTask.ID?
        
    let taskListMonitor: QueryMonitor<TaskListViewModel> = .init()
    let orphanMonitor: QueryMonitor<TaskListViewModel> = .init()
    
    let query: Database.Query
    
    init(query: Database.Query) {
        self.query = query
    }
    
    @State var taskSelection = Selection<KillerTask>()
    
    var body: some View {
        ScrollView {
            TaskListView(.orphaned, monitor: orphanMonitor, focus: $focusedTaskID)
                .padding(.horizontal, 16)
                .environment(\.taskListMonitor, self.taskListMonitor)
                .onChange(of: focusedTaskID) {
                    taskSelection.focus(focusedTaskID)
                }
        }
        .defaultScrollAnchor(.center)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    DoneButton(focusedTask: self.$focusedTaskID)
                    Spacer()
                    UndoButton()
                    RedoButton()
                }
                .buttonStyle(.bordered)
                
                NewTaskEntryField()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .environment(\.contextQuery, self.query)
        .environment(taskSelection)
        .task {
            guard let database else { return }
            await taskListMonitor.beginMonitoring(query, on: database)
        }
        .task {
            guard let database else { return }
            await orphanMonitor.beginMonitoring(query.compose(with: .orphaned), recursive: true, on: database)
        }
        .onDisappear {
            Task.detached {
                await taskListMonitor.stopMonitoring()
                await orphanMonitor.stopMonitoring()
            }
        }
    }
}


extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskListViewModel>? = nil
    @Entry var contextQuery: Database.Query? = nil
}

struct NewTaskEntryField: View {
    @State var enteredText: String = ""
    
    var body: some View {
        HStack {
            TextField("New Task", text: $enteredText)
            NewTaskButton(enteredText: $enteredText)
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background {
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.ultraThinMaterial)
        }
    }
}

struct NewTaskButton: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    @Environment(Selection<KillerTask>.self) var selection
    
    @Binding var enteredText: String
    
    var body: some View {
        Button("Add") {
            let currentText = enteredText
            enteredText = ""
            
            Task.detached {
                let query = await self.query
                await database?.insert(KillerTask.self, \.body <- currentText, \.parentID <- selection.focused, context: query)
            }
        }
    }
}

struct DoneButton: View {
    @Environment(\.database) var database
    var focusedTask: FocusState<KillerTask.ID?>.Binding
    
    var body: some View {
        Button("Done") {
            focusedTask.wrappedValue = nil
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
