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

struct TaskContainerView: View {
    @Environment(\.database) var database
    @Environment(\.navigationSizeClass) var navigationSizeClass
    @FocusState var focusedTaskID: KillerTask.ID?
        
    let taskListMonitor: QueryMonitor<TaskProvider> = .init()
    let orphanMonitor: QueryMonitor<TaskProvider> = .init()
    
    let scope: Database.Scope
    
    init(scope: Database.Scope) {
        self.scope = scope
    }
    
    @State var taskSelection = Selection<KillerTask>()
    
    var body: some View {
        CenteredScrollView {
            Text(scope.name)
                .lineLimit(1)
                .font(.title)
                .fontWeight(.semibold)
                .fadeOutScrollTransition()
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerPadding(axis: .horizontal)
            
            TaskListView(.orphaned, monitor: orphanMonitor)
                .environment(\.taskListMonitor, self.taskListMonitor)
                .onChange(of: focusedTaskID) {
                    Task {
                        try? await Task.sleep(for: .seconds(0.1))
                        Task { @MainActor in
                            taskSelection.choose(id: focusedTaskID)
                        }
                    }
                }
        }
        .containerPadding(axis: .horizontal)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
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
                
                NewTaskEntryField()
            }
            .containerPadding(axis: .horizontal)
            .padding(.bottom, 8)
        }
        .environment(\.focusedTaskID, $focusedTaskID)
        .environment(\.contextQuery, self.scope)
        .environment(taskSelection)
        .onAppear {
            guard let database else { return }
            
            Task.detached {
                await taskListMonitor.beginMonitoring(
                    scope,
                    on: database
                )
                
                await orphanMonitor.beginMonitoring(
                    scope.compose(with: .orphaned), recursive: true,
                    on: database
                )
            }
        }
        .onDisappear {
            Task.detached {
                await taskListMonitor.stopMonitoring()
                await orphanMonitor.stopMonitoring()
            }
        }
        .id(scope.id)
    }
}


extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskProvider>? = nil
    @Entry var contextQuery: Database.Scope? = nil
}

struct NewTaskEntryField: View {
    @SceneStorage("newTaskEntryText") var enteredText: String = ""
    
    var body: some View {
        HStack {
            TextField("New Task", text: $enteredText)
                .textFieldStyle(.plain)
            NewTaskButton(enteredText: $enteredText)
                .buttonStyle(KillerInlineButtonStyle())
        }
        .containerPadding()
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
                await database?.insert(KillerTask.self, \.body <- currentText, \.parentID <- selection.chosen, context: query)
            }
        }
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
