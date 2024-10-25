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
                CompleteButton(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
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
                CompleteButton(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
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
        .fadeOutScrollTransition()
    }
}

struct CompleteButton: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    
    @ScaledMetric private var checkboxWidth: Double = 16
    @ScaledMetric private var checkboxBorderWidth: Double = 1.5
    
    @State private var isOn: Bool
    
    private let delay: Duration = .seconds(0.3)
    
    let task: KillerTask
    
    init(task: KillerTask) {
        self.task = task
        self._isOn = State(initialValue: task.completedAt != nil)
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            ZStack {
                RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                    .strokeBorder(.gray, lineWidth: isOn ? 0  : self.checkboxBorderWidth)
                
                RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                    .foregroundStyle(isOn ? Color.accentColor : .clear)
                
                if isOn {
                    Image(systemName: "checkmark")
                        .resizable()
                        .fontWeight(.bold)
                        .foregroundStyle(isOn ? .white : .accentColor)
                        .padding(4)
                        .transition(.scale)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(width: self.checkboxWidth)
            .contentShape(Rectangle())
        }
        .toggleStyle(.button)
        .onChange(of: isOn) {
            let isOn = self.isOn
            Task.detached {
                try? await Task.sleep(for: self.delay)
                
                if isOn {
                    await database?.update(task, recursive: true, context: self.query, \.completedAt <- Date.now)
                }
                else {
                    await database?.update(task, recursive: true, context: self.query, \.completedAt <- nil)
                }
            }
        }
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
