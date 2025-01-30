import SwiftUI
import KillerModels

extension TaskView {
    struct BodyView: View {
        @Environment(Selection<KillerTask>.self) var selection
        @Environment(\.tasksPending) var pending
        
        let task: KillerTask
        
        private var bodyStr: String {
            task.body == "" ? "Enter a task" : task.body
        }
        
        var body: some View {
            if selection.chosen == self.task.id {
                BodyField(task: self.task)
            }
            else {
                Text(bodyStr)
                    .foregroundStyle(task.body == "" ? .tertiary : .primary)
            }
        }
    }
}
