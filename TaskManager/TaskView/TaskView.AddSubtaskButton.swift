import SwiftUI
import KillerModels
import KillerStyle

extension TaskView {
    struct AddSubtaskButton: View {
        @Environment(PendingTaskProvider.self) var newTaskContainer
        @Environment(Selection<KillerTask>.self) var selection
        
        let task: KillerTask
        
        init(for task: KillerTask) {
            self.task = task
        }
        
        var body: some View {
            HStack {
                if selection.chosen == task.id {
                    Button.async {
                        await newTaskContainer.push(shortCircuit: true)
                    } label: {
                        Label("Add Subtask", systemImage: "arrow.turn.down.right")
                    }
                    .foregroundStyle(.gray)
                    .buttonStyle(KillerInlineButtonStyle())
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                else {
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selection.chosen)
        }
    }
}
