import SwiftUI
import KillerModels
import KillerData
import UtilViews

// we need to update the textField when the DB value is updated elsewhere, but we
// don't want this change to propogate as though the user had typed something
//
// TextField state is different from DB state, so it gets messy!

struct TaskBodyField: View {
    @Environment(\.database) var database
    
    let task: KillerTask
    
    @State private var taskBody: String = ""
    
    var body: some View {
        DebouncedTextField("Task", text: $taskBody)
            .textFieldStyle(.plain)
            .onLocalChange(of: $taskBody, source: task.body, setupFromSource: true) {
                Task.detached {
                    await database?.update(task, \.body <- taskBody)
                }
            }
    }
}
