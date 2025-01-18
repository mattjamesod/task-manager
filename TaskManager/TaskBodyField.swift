import SwiftUI
import KillerModels
import KillerData
import UtilViews

struct TaskBodyField: View {
    @Environment(\.database) var database
    
    let task: KillerTask
    private let emptyText: String = "Enter a task"
    
    @State private var taskBody: String = ""
    
    var body: some View {
        DebouncedTextField(emptyText, text: $taskBody)
            .textFieldStyle(.plain)
            .onLocalChange(of: $taskBody, source: task.body, setupFromSource: true) {
                guard permit() else { return }
                
                Task.detached {
                    await database?.upsert(task, \.body <- taskBody)
                }
            }
    }
    
    private func permit() -> Bool {
        taskBody = String(taskBody.prefix(KillerTask.maxBodyLength))
        return taskBody != task.body
    }
}
