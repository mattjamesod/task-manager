import SwiftUI
import KillerModels
import KillerStyle
import KillerData

extension EnvironmentValues {
    @Entry var tasksPending: Bool = false
}

extension View {
    func tasksPending(_ on: Bool = true) -> some View {
        self.environment(\.tasksPending, on)
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
        
    let task: KillerTask
    
    // TODO: return false if task already has children
    private var showSubtaskButton: Bool {
        !pending && (contextQuery?.allowsTaskEntry ?? false)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            CompleteOrDeleteMetaData(.leading, task: task)
            
            VStack(alignment: .leading) {
                BodyView(task: self.task)
                if showSubtaskButton {
                    AddSubtaskButton(for: self.task)
                }
            }
            
            Spacer()
            
            CompleteOrDeleteMetaData(.trailing, task: task)
        }
        .fixedSize(horizontal: false, vertical: true)
        .containerPadding()
        .contentShape(Rectangle())
        .background(SelectionBackground(task: self.task))
        .allowsTaskSelection(of: task)
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
                await database?.update(task, recursive: true, context: query, \.deletedAt <<- Date.now)
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
