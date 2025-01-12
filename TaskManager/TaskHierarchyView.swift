import SwiftUI
import UtilViews
import AsyncAlgorithms
import KillerStyle
import KillerModels
import KillerData

@Observable @MainActor
final class Selection<T: Identifiable> {
    private(set) var ids: [T.ID] = []
    
    var chosen: T.ID? {
        ids.count == 1 ? ids.first! : nil
    }
    
    var last: T.ID? {
        ids.last
    }
    
    func choose(_ obj: T) {
        choose(id: obj.id)
    }
    
    func choose(id: T.ID?) {
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

extension EnvironmentValues {
    @Entry var focusedTaskID: FocusState<KillerTask.ID?>.Binding?
}

@Observable @MainActor
class TaskHierarchyViewModel {
    let taskListMonitor: QueryMonitor<TaskContainer> = .init()
    let orphanMonitor: QueryMonitor<TaskContainer> = .init()
    
    let query: Database.Scope
    
    init(query: Database.Scope) {
        self.query = query
    }
    
    var title: String {
        query.name
    }
    
    nonisolated func startMonitoring(_ database: Database) async {
        await taskListMonitor.waitForChanges(
            query, on: database
        )
        
        await orphanMonitor.waitForChanges(
            query.compose(with: .orphaned), recursive: true, on: database
        )
    }
    
    nonisolated func stopMonitoring(database: Database) async {
        await taskListMonitor.stopMonitoring(database: database)
        await orphanMonitor.stopMonitoring(database: database)
    }
}

extension TaskHierarchyView {
    struct EmptyView: View {
        var body: some View {
            VStack(spacing: 8) {
                Text("Nothing Here")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Add a new task or edit this scope")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.gray)
        }
    }
}

// shows a progress veiw if it's taking a while to render something else
struct EventuallyProgressView: View {
    @State var takingAWhile = false
    
    var body: some View {
        ProgressView()
            .opacity(takingAWhile ? 1 : 0)
            .task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                takingAWhile = true
            }
    }
}

struct TaskHierarchyView: View {
    @Environment(\.database) var database
    @Environment(\.navigationSizeClass) var navigationSizeClass
    @FocusState var focusedTaskID: KillerTask.ID?
    
    @State var viewModel: TaskHierarchyViewModel
    @State var newTaskMonitor: NewTaskMonitor = .init(parentID: nil)
    @State var taskSelection = Selection<KillerTask>()
    @State var state: TaskContainerState = .loading
    
    init(scope: Database.Scope) {
        self.viewModel = .init(query: scope)
    }
    
    var body: some View {
        ZStack {
            CenteredScrollView {
                HStack {
                    Text(viewModel.title)
                        .lineLimit(1)
                        .font(.title)
                        .fontWeight(.semibold)
                }
                .fadeOutScrollTransition()
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerPadding(axis: .horizontal)
                
                TaskListView(.orphaned, monitor: viewModel.orphanMonitor)
                    .environment(newTaskMonitor)
                    .environment(\.taskListMonitor, viewModel.taskListMonitor)
                    .onChange(of: focusedTaskID) {
                        Task {
                            try? await Task.sleep(for: .seconds(0.1))
                            Task { @MainActor in
                                taskSelection.choose(id: focusedTaskID)
                            }
                        }
                    }
            }
            .opacity(state.isDone ? 1 : 0)
                
            if state == .empty {
                EmptyView()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            if state == .loading {
                EventuallyProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.bouncy(duration: 0.4), value: state)
        .containerPadding(axis: .horizontal)
        .safeAreaInset(edge: .bottom) {
            HStack {
                if focusedTaskID != nil {
                    DoneButton()
                }
                Spacer()
                Group {
                    UndoButton()
                    RedoButton()
                }
                .opacity(DeviceKind.current.isMobile ? 1 : 0)
            }
            .buttonStyle(KillerBorderedButtonStyle())
            .containerPadding(axis: .horizontal)
            .padding(.bottom, 8)
        }
        .onPreferenceChange(TaskContainerStateKey.self) { state in
            Task {
                self.state = state
            }
        }
        .environment(\.focusedTaskID, $focusedTaskID)
        .environment(\.contextQuery, viewModel.query)
        .environment(taskSelection)
        .task {
            guard let database else { return }
            await viewModel.startMonitoring(database)
        }
        .onDisappear {
            guard let database else { return }
            Task {
                await viewModel.stopMonitoring(database: database)
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskContainer>? = nil
    @Entry var contextQuery: Database.Scope? = nil
}

struct DoneButton: View {
    @Environment(\.database) var database
    @Environment(\.focusedTaskID) var focusedTaskID
    
    var body: some View {
        Button("Done") {
            focusedTaskID?.wrappedValue = nil
        }
        .keyboardShortcut(.escape, modifiers: [])
    }
}

struct UndoButton: View {
    @Environment(\.database) var database
    @Environment(\.canUndo) var canUndo
    
    var body: some View {
        Button("Undo") {
            Task.detached {
                await database?.undo()
            }
        }
        .disabled(!canUndo)
    }
}

struct RedoButton: View {
    @Environment(\.database) var database
    @Environment(\.canRedo) var canRedo
    
    var body: some View {
        Button("Redo") {
            Task.detached {
                await database?.redo()
            }
        }
        .disabled(!canRedo)
    }
}

extension Button {
    static func async(
        action: @Sendable @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(action: { Task.detached { await action() }}, label: label)
    }
    static func async(
        role: ButtonRole,
        action: @Sendable @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(role: role, action: { Task.detached { await action() }}, label: label)
    }
}
