import SwiftUI
import KillerData
import KillerModels

struct TaskWithChildrenView: View {
    @Environment(\.focusedTaskID) var focusedTaskID
    
    @State var pendingTaskProvider: PendingTaskProvider
    
    init(task: KillerTask, context: Database.Scope?) {
        self.task = task
        
        let listContext = context?.compose(with: .children(of: task.id))
        self.pendingTaskProvider = .init(listContext: listContext)
    }
    
    let task: KillerTask
    
    var body: some View {
        TaskSpacing {
            TaskView(task: task)
                .focused(focusedTaskID!, equals: task.id)
            TaskListView(parentID: task.id)
                .padding(.leading, 24)
        }
        .environment(pendingTaskProvider)
    }
}
