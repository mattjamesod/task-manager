import SwiftUI
import KillerData
import KillerModels

struct TaskWithChildrenView: View {
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
            TaskListView(parentID: task.id, monitor: taskListMonitor)
                .id(task.id)
                .padding(.leading, 24)
        }
        .environment(pendingTaskProvider)
    }
}

struct AllowsTaskSelectionViewModifier: ViewModifier {
    @Environment(Selection<KillerTask>.self) var selection
    @FocusState var isFocused: Bool
    
    init(task: KillerTask) {
        self.task = task
    }
    
    let task: KillerTask
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onTapGesture {
                isFocused = true
                selection.choose(self.task)
            }
    }
}

extension View {
    func allowsTaskSelection(of task: KillerTask) -> some View {
        self.modifier(AllowsTaskSelectionViewModifier(task: task))
    }
}
