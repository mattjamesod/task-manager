import SwiftUI
import KillerData
import KillerModels

struct TaskWithChildrenView: View {
    @Environment(Selection<KillerTask>.self) var selection
    @Environment(\.taskListMonitor) var taskListMonitor
    
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
                .id(task.id)
                .onTapGesture {
                    selection.repeatedlyChoose(self.task)
                }
            TaskListView(parentID: task.id, monitor: taskListMonitor)
                .id(task.id)
                .padding(.leading, 24)
        }
        .environment(pendingTaskProvider)
    }
}
