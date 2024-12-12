import SwiftUI
import KillerModels
import KillerData
import KillerStyle

struct TaskEntryField: View {
    @SceneStorage("newTaskEntryText") var enteredText: String = ""
    
    var body: some View {
        HStack {
            TextField("New Task", text: $enteredText)
                .textFieldStyle(.plain)
            NewTaskButton(enteredText: $enteredText)
                .buttonStyle(KillerInlineButtonStyle())
        }
        .containerPadding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.ultraThinMaterial)
        }
    }
}

struct NewTaskButton: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    @Environment(Selection<KillerTask>.self) var selection
    
    @Binding var enteredText: String
    
    private var sanitisedText: String {
        String(enteredText.prefix(4000))
    }
    
    var body: some View {
        Button("Add") {
            let currentText = sanitisedText
            enteredText = ""
            
            Task.detached {
                let query = await self.query
                await database?.insert(
                    KillerTask.self,
                    \.body <- currentText,
                    \.parentID <- selection.chosen,
                    context: query
                )
            }
        }
        .disabled(enteredText.isEmpty)
    }
}
