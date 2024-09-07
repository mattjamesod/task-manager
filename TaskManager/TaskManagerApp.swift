import SwiftUI
import KillerData

struct NavigationStackOption: Identifiable {
    let id: Int
    let title: String
    let query: Database.Query
}

extension NavigationStackOption: Hashable {
    static func == (lhs: NavigationStackOption, rhs: NavigationStackOption) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }
}

@main
struct TaskManagerApp: App {
    let database: Database?
    
    init() {
        do {
            self.database = try DatabaseSetupHelper(schema: .userData).setup()
        }
        catch {
            // TODO: log database setup error
            self.database = nil
        }
    }
    
    @State var presentedOptions: [NavigationStackOption] = []
    
    let options: [NavigationStackOption] = [
        .init(id: 0, title: "Active", query: .allActiveTasks),
        .init(id: 1, title: "Completed", query: .completedTasks),
        .init(id: 2, title: "Recently Deleted", query: .deletedTasks)
    ]
        
    var body: some Scene {
        WindowGroup {
            if let database {
                VStack(spacing: 0) {
                    TaskContainerView(query: .allActiveTasks)
                        .environment(\.database, database)
//                    TaskContainerView(query: .allActiveTasks)
//                        .environment(\.database, database)
//                        .border(.blue)
                }
                
//                NavigationStack {
//                    List(options) { option in
//                        NavigationLink(option.title, value: option)
//                    }
//                    .navigationDestination(for: NavigationStackOption.self) {
//                        TaskContainerView(query: $0.query)
//                            .environment(\.database, database)
//                    }
//                }
            }
            else {
                CatastrophicErrorView()
            }
        }
//        .backgroundTask(.appRefresh("RECENTLY_DELETED_PURGE")) {
//
//        }
    }
}

struct CatastrophicErrorView: View {
    var body: some View {
        VStack(spacing: 36) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.red)
                .frame(maxWidth: 72)
            
            Text("An unexpected problem has occurred")
                .font(.title3)
                .foregroundStyle(.gray)
            
            // TODO: add helpful links/info here
        }
    }
}
