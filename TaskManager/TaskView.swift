import SwiftUI
import KillerModels
import KillerStyle
import KillerData

fileprivate extension EnvironmentValues {
    @Entry var taskCompleteButtonPosition: TaskView.CompleteButtonPosition = .leading
}

extension EnvironmentValues {
    @Entry var tasksPending: Bool = false
}

extension View {
    func taskCompleteButton(position: TaskView.CompleteButtonPosition) -> some View {
        self.environment(\.taskCompleteButtonPosition, position)
    }
    
    func tasksPending(_ on: Bool = true) -> some View {
        self.environment(\.tasksPending, on)
    }
}

extension TaskView {
    struct CompleteOrDeleteMetaData: View {
        @Environment(\.taskCompleteButtonPosition) var desiredPosition
        
        let thisPosition: CompleteButtonPosition
        let task: KillerTask
        
        init(_ thisPosition: CompleteButtonPosition, task: KillerTask) {
            self.thisPosition = thisPosition
            self.task = task
        }
        
        var body: some View {
            if thisPosition == desiredPosition {
                TaskCompleteCheckbox(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
                    .id(task.instanceID)
            }
            else if let deletedAt = self.task.deletedAt {
                WillBeDeletedInMessage(deletedAt: deletedAt)
            }
        }
    }
    
    struct WillBeDeletedInMessage: View {
        @State var message: String = ""
        
        let deletedAt: Date
        
        var body: some View {
            Text(self.message)
                .font(.caption)
                .foregroundStyle(.red)
                .onAppear {
                    let formatter = DateComponentsFormatter()
                    
                    formatter.unitsStyle = .abbreviated
                    formatter.allowedUnits = [.day, .hour, .minute]
                    formatter.maximumUnitCount = 1
                    
                    self.message = formatter.string(from: 30.days.ago, to: deletedAt) ?? ""
                }
        }
    }
    
    struct AddSubtaskButton: View {
        @Environment(\.database) var database
        @Environment(\.contextQuery) var query
        @Environment(PendingTaskProvider.self) var newTaskContainer
        
        let task: KillerTask
        
        var body: some View {
            Button.async {
                await newTaskContainer.push(shortCircuit: true)
            } label: {
                Label("Add Subtask", systemImage: "arrow.turn.down.right")
            }
        }
    }
}

struct TaskView: View {
    enum CompleteButtonPosition {
        case leading
        case trailing
    }
    
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.tasksPending) var pending
    @Environment(\.taskCompleteButtonPosition) var completeButtonPosition
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    // TODO: return false if task already has children
    private var showSubtaskButton: Bool {
        let allowsTaskEntry = contextQuery?.allowsTaskEntry ?? false
        let shouldEverShowButton = !pending && allowsTaskEntry
        
        return shouldEverShowButton && selection.chosen == task.id
    }
    
    var body: some View {
        HStack {
            CompleteOrDeleteMetaData(.leading, task: task)
            
            VStack(alignment: .leading) {
                TaskBodyField(task: self.task)
                
                if showSubtaskButton {
                    AddSubtaskButton(task: self.task)
                        .foregroundStyle(.gray)
                        .buttonStyle(KillerInlineButtonStyle())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selection.chosen)
            
            Spacer()
            
            CompleteOrDeleteMetaData(.trailing, task: task)
        }
        .fixedSize(horizontal: false, vertical: true)
        .containerPadding()
        .contentShape(Rectangle())
        .background {
            ZStack {
                Rectangle()
                    .foregroundStyle(Color.clear)
                if selection.ids.contains(task.id) {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(.ultraThinMaterial)
                }
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .contextMenu {
            Button.async {
                await database?.duplicate(task)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Divider()
            Button.async(role: .destructive) {
                let query = await self.contextQuery
                await database?.update(task, recursive: true, context: query, \.deletedAt <- Date.now)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .fadeOutScrollTransition()
    }
}

extension View {
    func fadeOutScrollTransition() -> some View {
        self.scrollTransition(axis: .vertical) { content, phase in
            let phases: [ScrollTransitionPhase] = [.topLeading, .bottomTrailing]
            
            let applies = phases.contains(phase)
            
            return content
                .opacity(applies ? 0.5 : 1.0)
                .blur(radius: applies ? 2 : 0)
                .scaleEffect(
                    x: applies ? 0.98 : 1,
                    y: applies ? 1.2 : 1,
                    anchor: phase == .topLeading ? .bottom : .top
                )
        }
    }
}
