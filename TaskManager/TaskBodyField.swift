import SwiftUI
import KillerModels
import KillerData
import UtilViews

// sanitising the input to a max length is tricky, because we want to trim DB input,
// but the result won't get reflected back to the UI...

struct TaskBodyField: View {
    @Environment(\.database) var database
    
    let task: KillerTask
    
    @State private var taskBody: String = ""
    
    var body: some View {
        DebouncedTextField("Task", text: $taskBody)
            .textFieldStyle(.plain)
            .onLocalChange(of: $taskBody, source: task.body, setupFromSource: true) {
                taskBody = String(taskBody.prefix(4000))
                
                Task.detached {
                    await database?.update(task, \.body <- taskBody)
                }
            }
    }
}
