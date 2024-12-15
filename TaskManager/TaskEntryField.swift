import SwiftUI
import KillerModels
import KillerData
import KillerStyle
import UtilViews

struct TaskEntryField: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    @Environment(Selection<KillerTask>.self) var selection
    
    @State var enteredText: String = ""
    
    var body: some View {
        HStack {
            DebouncedTextField("New Task", text: $enteredText)
                .textFieldStyle(.plain)
                .onChange(of: enteredText) {
                    let currentText = String(enteredText.prefix(KillerTask.maxBodyLength))
                    guard !enteredText.isEmpty else { return }
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
        }
        .containerPadding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .foregroundStyle(.ultraThinMaterial)
        }
    }
}

