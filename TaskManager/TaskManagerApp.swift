import SwiftUI
import KillerData

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
    
    var body: some Scene {
        WindowGroup {
            if let database {
                VStack {
                    TaskContainerView(query: .allActiveTasks)
                        .environment(\.database, database)
                        .border(.blue)
                    TaskContainerView(query: .deletedTasks)
                        .environment(\.database, database)
                        .border(.red)
                }
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
