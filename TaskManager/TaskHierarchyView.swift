import SwiftUI
import UtilViews
import KillerData

extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskContainer>? = nil
    @Entry var contextQuery: Database.Scope<KillerTask>? = nil
}

@Observable @MainActor
class TaskHierarchyViewModel {
    let taskListMonitor: QueryMonitor<TaskContainer> = .init()
    let orphanMonitor: QueryMonitor<TaskContainer> = .init()
    
    let query: Database.Scope<KillerTask>
    
    init(query: Database.Scope<KillerTask>) {
        self.query = query
    }
    
    var title: String {
        query.name
    }
    
    nonisolated func startMonitoring(_ database: Database) async {
        await taskListMonitor.waitForChanges(
            query, on: database
        )
        
        await orphanMonitor.waitForChanges(
            query.compose(with: HardcodedScopes.orphaned), recursive: true, on: database
        )
    }
    
    nonisolated func stopMonitoring(database: Database) async {
        await taskListMonitor.stopMonitoring(database: database)
        await orphanMonitor.stopMonitoring(database: database)
    }
}

struct TaskHierarchyView: View {
    @Environment(\.database) var database
    
    @State var viewModel: TaskHierarchyViewModel
    
    init(scope: Database.Scope<KillerTask>) {
        self.viewModel = .init(query: scope)
    }
    
    var body: some View {
        CenteredScrollView {
            HStack {
                Text(viewModel.title)
                    .lineLimit(1)
                    .font(.title)
                    .fontWeight(.semibold)
            }
            .fadeOutScrollTransition()
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerPadding(axis: .horizontal)
            
            TaskListView(HardcodedScopes.orphaned, monitor: viewModel.orphanMonitor)
                .environment(\.taskListMonitor, viewModel.taskListMonitor)
        }
        .environment(\.contextQuery, viewModel.query)
        .task {
            guard let database else { return }
            await viewModel.startMonitoring(database)
        }
        .onDisappear {
            guard let database else { return }
            Task {
                await viewModel.stopMonitoring(database: database)
            }
        }
    }
}
