import SwiftUI
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

extension TaskScopeView {
    struct EmptyView: View {
        @Environment(PendingTaskProvider.self) var newTaskContainer
        
        var body: some View {
            VStack(spacing: 8) {
                Text("Nothing Here")
                    .font(.title)
                    .fontWeight(.bold)
                Button.async {
                    await newTaskContainer.push(shortCircuit: true)
                } label: {
                    Text("Add a Task")
                }
                .buttonStyle(KillerBorderedButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.gray)
        }
    }
}

struct AfterDurationViewModifier: ViewModifier {
    private let duration: Duration
    private let callback: () -> ()
    
    init(_ duration: Duration, _ callback: @escaping () -> ()) {
        self.duration = duration
        self.callback = callback
    }
    
    func body(content: Content) -> some View {
        content
            .task {
                try? await Task.sleep(for: self.duration)
                callback()
            }
    }
}

extension View {
    func after(_ duration: Duration, _ callback: @escaping () -> ()) -> some View {
        self.modifier(AfterDurationViewModifier(duration, callback))
    }
}

// shows a progress veiw if it's taking a while to render something else
struct EventuallyProgressView: View {
    @State var takingAWhile = false
    
    var body: some View {
        ProgressView()
            .opacity(takingAWhile ? 1 : 0)
            .after(.seconds(1)) {
                takingAWhile = true
            }
    }
}

struct TaskScopeView: View {
    @Environment(\.database) var database
    @Environment(\.navigationSizeClass) var navigationSizeClass
    
    @FocusState var focusedTaskID: KillerTask.ID?
    @State var taskSelection = Selection<KillerTask>()
    @State var state: TaskContainerState = .loading
    @State var pendingTaskProvider: PendingTaskProvider
    
    let scope: Database.Scope
    
    init(scope: Database.Scope) {
        self.scope = scope
        self.pendingTaskProvider = .init(listContext: scope)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            TaskHierarchyView(scope: self.scope)
                .environment(pendingTaskProvider)
                .onChange(of: focusedTaskID) {
                    Task {
                        try? await Task.sleep(for: .seconds(0.1))
                        Task { @MainActor in
                            taskSelection.choose(id: focusedTaskID)
                        }
                    }
                }
                .opacity(state.isDone ? 1 : 0)
                
            if state == .empty {
                EmptyView()
                    .environment(pendingTaskProvider)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            if state == .loading {
                EventuallyProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            Button("break") {
                print("-------")
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
            Task { @MainActor in
                self.state = state
            }
        }
        .environment(\.focusedTaskID, $focusedTaskID)
        .environment(taskSelection)
    }
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
