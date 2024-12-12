import SwiftUI
import KillerModels
import KillerData
import UtilViews

struct TaskBodyField: View {
    @Environment(\.database) var database
    
    let task: KillerTask
    
    @State private var taskBody: String = ""
    
    var body: some View {
        DebouncedTextField("Task", text: $taskBody)
            .textFieldStyle(.plain)
            .onLocalChange(of: $taskBody, source: task.body, setupFromSource: true) {
                guard permit() else { return }
                
                Task.detached {
                    await database?.update(task, \.body <- taskBody)
                }
            }
    }
    
    private func permit() -> Bool {
        taskBody = String(taskBody.prefix(4000))
        return taskBody != task.body
    }
}
