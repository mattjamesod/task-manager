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
//                    let taskBody = await self.taskBody
//                    if taskBody.isEmpty {
//                        await database?.delete(KillerTask.self, task.id)
//                    }
//                    else {
                        await database?.upsert(task, \.body <- taskBody)
//                    }
                }
            }
    }
    
    private func permit() -> Bool {
        taskBody = String(taskBody.prefix(KillerTask.maxBodyLength))
        return taskBody != task.body
    }
}
