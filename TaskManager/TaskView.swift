import SwiftUI
import UtilViews
import KillerModels
import KillerData

struct TaskView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    @State var editing: Bool = false
    @State var editingTaskBody: String = ""
    
    var body: some View {
        HStack {
            CompleteButton(task: self.task)
            
            VStack {
                DebouncedTextField("Task", text: $editingTaskBody)
                    .onChange(of: editingTaskBody) {
                        Task.detached {
                            await database?.update(task, \.body <- editingTaskBody)
                        }
                    }
                if selection.ids.contains(task.id) {
                    Text("metadata").foregroundStyle(.gray)
                }
            }
            .onAppear {
                self.editingTaskBody = task.body
            }
            .onChange(of: task.body) {
                self.editingTaskBody = task.body
            }
            
            Spacer()
        }
        .padding(8)
        .background {
            if selection.ids.contains(task.id) {
                Rectangle().foregroundStyle(.ultraThinMaterial)
            }
        }
        .onTapGesture {
            selection.pick(task)
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
            Button {
                editingTaskBody = task.body
                self.editing.toggle()
            } label: {
                Label("Edit", systemImage: "arrow.down")
            }
        })
    }
}

struct CompleteButton: View {
    @Environment(\.database) var database
    
    let task: KillerTask
    
    var body: some View {
        Button.async(action: { await database?.update(task, recursive: true, \.completedAt <- Date.now) }) {
            Label("Complete", systemImage: "checkmark")
                .labelStyle(.iconOnly)
        }
    }
}
