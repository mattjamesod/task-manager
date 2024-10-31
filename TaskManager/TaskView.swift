import SwiftUI
import KillerModels
import KillerStyle
import KillerData

fileprivate extension EnvironmentValues {
    @Entry var taskCompleteButtonPosition: TaskView.CompleteButtonPosition = .leading
}

extension View {
    func taskCompleteButton(position: TaskView.CompleteButtonPosition) -> some View {
        self.environment(\.taskCompleteButtonPosition, position)
    }
}

struct TaskView: View {
    enum CompleteButtonPosition {
        case leading
        case trailing
    }
    
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(\.taskCompleteButtonPosition) var completeButtonPosition
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    var body: some View {
        HStack {
            if completeButtonPosition == .leading {
                TaskCompleteCheckbox(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
                    .id(task.instanceID)
            }
            
            VStack(alignment: .leading) {
                TaskBodyField(task: self.task)
                
                if selection.chosen == task.id {
                    AddSubtaskButton(task: self.task)
                        .foregroundStyle(.gray)
                        .buttonStyle(KillerInlineButtonStyle())
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selection.chosen)
            
            Spacer()
            
            if completeButtonPosition == .trailing {
                TaskCompleteCheckbox(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
                    .id(task.instanceID)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .containerPadding()
        .background {
            if selection.ids.contains(task.id) {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(.ultraThinMaterial)
            }
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .contextMenu(menuItems: {
            Button.async {
                let query = await self.contextQuery
                await database?.update(task, recursive: true, context: query, \.deletedAt <- Date.now)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button.async {
                await database?.duplicate(task)
            } label: {
                Label("Duplicate", systemImage: "square.on.square")
            }
        })
        .fadeOutScrollTransition()
    }
}

struct AddSubtaskButton: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    
    let task: KillerTask
    
    var body: some View {
        Button.async {
        	await database?.insert(KillerTask.self, \.parentID <- task.id, context: self.query)
        } label: {
            Label("Add Subtask", systemImage: "arrow.turn.down.right")
        }
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
