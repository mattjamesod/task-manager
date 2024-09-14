import SwiftUI
import KillerData

extension EnvironmentValues {
    @Entry var selectedScope: Binding<Database.Scope?>?
}

struct ScopeNavigation: View {
    @State var selectedScope: Database.Scope? = nil
    
    var body: some View {
        Group {
            if let selectedScope {
                TaskContainerView(query: selectedScope)
                    .environment(\.selectedScope, $selectedScope)
                    .transition(.move(edge: .trailing))
            }
            else {
                ScopeListView(selectedScope: self.$selectedScope)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.snappy(duration: 0.3), value: self.selectedScope)
    }
}

struct DynamicBackButton: View {
    @Environment(\.selectedScope) var selectedScope
    
    var body: some View {
        if let scope = self.selectedScope  {
            Button {
                scope.wrappedValue = nil
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
        }
    }
}

struct ScopeListView: View {
    let hardCodedScopes: [Database.Scope] = [
        .allActiveTasks,
        .completedTasks,
        .deletedTasks
    ]
    
    @Binding var selectedScope: Database.Scope?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(self.hardCodedScopes) { scope in
                    Button {
                        selectedScope = scope
                    } label: {
                        Label(scope.name, systemImage: "chevron.right")
                    }
                }
                .fadeOutScrollTransition()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .safeAreaInset(edge: .top) {
            Text("Scopes")
                .font(.title)
                .fontWeight(.semibold)
        }
    }
}
