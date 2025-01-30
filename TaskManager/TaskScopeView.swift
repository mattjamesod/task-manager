import SwiftUI
import AsyncAlgorithms
import KillerStyle
import KillerModels
import KillerData

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

// shows a progress view if it's taking a while to render something else
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
        }
        .animation(.bouncy(duration: 0.4), value: state)
        .containerPadding(axis: .horizontal)
        .safeAreaInset(edge: .bottom) {
            HStack {
                if taskSelection.chosen != nil {
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
        .environment(taskSelection)
    }
}

struct DoneButton: View {
    @Environment(Selection<KillerTask>.self) var selection
    @Environment(\.database) var database
    
    var body: some View {
        Button("Done") {
            selection.clear()
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
