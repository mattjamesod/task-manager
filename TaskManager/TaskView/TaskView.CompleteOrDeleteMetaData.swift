import SwiftUI
import KillerModels
import KillerStyle

fileprivate extension EnvironmentValues {
    @Entry var taskCompleteButtonPosition: TaskView.CompleteButtonPosition = .leading
}

extension View {
    func taskCompleteButton(position: TaskView.CompleteButtonPosition) -> some View {
        self.environment(\.taskCompleteButtonPosition, position)
    }
}

extension TaskView {
    struct CompleteOrDeleteMetaData: View {
        @Environment(\.taskCompleteButtonPosition) var desiredPosition
        @Environment(\.tasksPending) var pending
        
        let thisPosition: CompleteButtonPosition
        let task: KillerTask
        
        init(_ thisPosition: CompleteButtonPosition, task: KillerTask) {
            self.thisPosition = thisPosition
            self.task = task
        }
        
        var body: some View {
            if thisPosition == desiredPosition {
                ZStack {
                    Checkbox.Pending()
                        .opacity(pending ? 1 : 0)
                    
                    Checkbox(task: self.task)
                        .buttonStyle(KillerInlineButtonStyle())
                        .id(task.instanceID)
                        .opacity(pending ? 0 : 1)
                }
            }
            else if let deletedAt = self.task.deletedAt {
                WillBeDeletedInMessage(deletedAt: deletedAt)
            }
        }
    }
}
