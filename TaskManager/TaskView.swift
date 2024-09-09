import SwiftUI
import KillerModels
import KillerData

struct TaskView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    var body: some View {
        HStack {
            CompleteButton(task: self.task)
            
            VStack(alignment: .leading) {
                TaskBodyField(task: self.task)
                
                if selection.focused == task.id {
                    Text("metadata")
                        .foregroundStyle(.gray)
                }
            }
            
            Spacer()
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
    @Environment(\.contextQuery) var contextQuery
    
    let task: KillerTask
    
    var body: some View {
        Button.async(action: { await database?.update(task, recursive: true, context: contextQuery, \.completedAt <- Date.now) }) {
            Label("Complete", systemImage: "checkmark")
                .labelStyle(.iconOnly)
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
