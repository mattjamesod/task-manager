import SwiftUI
import KillerData
import KillerModels

struct TaskWithChildrenView: View {
    @State var pendingTaskProvider: PendingTaskProvider
    
    init(task: KillerTask, context: Database.Scope?) {
        self.task = task
        
        let listContext = context?.compose(with: .children(of: task.id))
        self.pendingTaskProvider = .init(listContext: listContext)
    }
    
    let task: KillerTask
    
    var body: some View {
        Self._printChanges()
        return TaskSpacing {
            TaskView(task: task)
                .id(task.id)
            TaskListView(parentID: task.id)
                .id(task.id)
                .padding(.leading, 24)
        }
        .environment(pendingTaskProvider)
    }
}
