import SwiftUI
import KillerModels
import KillerData

struct TaskView: View {
    enum CompleteButtonPosition {
        case leading
        case trailing
    }
    
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    let completeButtonPosition: CompleteButtonPosition = .leading
    
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
                }
            }
            
            Spacer()
            
            if completeButtonPosition == .trailing {
                CompleteButton(task: self.task)
                    .buttonStyle(KillerInlineButtonStyle())
            }
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
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
    
    @ScaledMetric var checkboxWidth: Double = 16
    @State var isOn: Bool
    
    let task: KillerTask
    
    init(task: KillerTask) {
        self.task = task
        self._isOn = State(initialValue: task.completedAt != nil)
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            ZStack {
                RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                    .strokeBorder(isOn ? .blue : .gray, lineWidth: 2)
                
                if isOn {
                    RoundedRectangle(cornerRadius: (self.checkboxWidth / 3) - 4)
                        .foregroundStyle(.blue)
                        .padding(4)
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
            #if(os(iOS))
            let phases: [ScrollTransitionPhase] = [.topLeading, .bottomTrailing]
            #else
            let phases: [ScrollTransitionPhase] = [.topLeading]
            #endif
            
            let applies = phases.contains(phase)
            
            return content
                .opacity(applies ? 0.5 : 1.0)
                .blur(radius: applies ? 1 : 0)
                .scaleEffect(applies ? 0.9 : 1, anchor: .center)
        }
    }
}
