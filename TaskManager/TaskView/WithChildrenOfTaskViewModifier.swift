import SwiftUI
import KillerData
import KillerModels

extension View {
    func withChildren(of task: KillerTask, context: Database.Scope<KillerTask>? = nil) -> some View {
        modifier(WithChildrenOfTaskViewModifier(task: task, context: context))
    }
}

fileprivate struct WithChildrenOfTaskViewModifier: ViewModifier {
    @Environment(\.taskListMonitor) var taskListMonitor
    @State var pendingTaskProvider: PendingTaskProvider
    
    init(task: KillerTask, context: Database.Scope<KillerTask>?) {
        self.task = task
        
        let listContext = HardcodedScopes.children(of: task.id).compose(with: context)
        self.pendingTaskProvider = .init(listContext: listContext)
    }
    
    let task: KillerTask
    
    func body(content: Content) -> some View {
        TaskSpacing {
            content
                .id(task.id)
            TaskListView(parentID: task.id, monitor: taskListMonitor)
                .padding(.leading, 24)
        }
        .environment(pendingTaskProvider)
    }
}
