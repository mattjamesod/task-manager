import SwiftUI
import KillerModels
import KillerData

struct TaskView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    @FocusState var bodyFieldFocused: Bool
    
    var body: some View {
        HStack {
            CompleteButton(task: self.task)
            
            VStack(alignment: .leading) {
                TaskBodyField(task: self.task)
                    .focused($bodyFieldFocused)
                    .onChange(of: bodyFieldFocused) {
                        if bodyFieldFocused {
                            selection.pick(task)
                        }
                    }
                
                if selection.ids.contains(task.id) {
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
