import SwiftUI
import UtilViews
import KillerModels
import KillerData

struct TaskView: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var contextQuery
    @Environment(Selection<KillerTask>.self) var selection
        
    let task: KillerTask
    
    @State var textFieldInput: String = ""
    @State var ignoreTextFieldInputUpdate: Bool = false
    
    var body: some View {
        HStack {
            CompleteButton(task: self.task)
            
            VStack {
                DebouncedTextField("Task", text: $textFieldInput)
                
                if selection.ids.contains(task.id) {
                    Text("metadata")
                        .foregroundStyle(.gray)
                }
            }
            // we need to update the textField when the DB value is updated, but we
            // don't want this change to propogate as though the user had typed something
            //
            // TextField state is different from DB state, so it gets messy!
            .onChange(of: textFieldInput) {
                guard !ignoreTextFieldInputUpdate else {
                    ignoreTextFieldInputUpdate = false
                    return
                }
                
                Task.detached {
                    await database?.update(task, \.body <- textFieldInput)
                }
            }
            .onChange(of: task.body, initial: true) {
                self.ignoreTextFieldInputUpdate = true
                self.textFieldInput = task.body
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
