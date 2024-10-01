import SwiftUI
import KillerData

enum NavigationSizeClass {
    case regular
    case compact
}

extension EnvironmentValues {
    @Entry var selectedScope: Binding<Database.Scope?>?
    @Entry var navigationSizeClass: NavigationSizeClass = .regular
}

// The problem:

// starting the macOS app with more than one window, where one is mobile, the sync engine
// just totally craps the bed

// if they're all desktop, it's fine

// chaning their size after boot is also fine

// the issue must be with view that fits: the second listed view behaves weird

// EVEN IF the second view is just text

struct ScopeNavigation: View {
    @State var selection: Database.Scope?
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            
            // widescreen desktop view
            
            HStack(spacing: 0) {
                ScopeListView(selectedScope: self.$selection)
                    .frame(width: 300)
                
                Divider().ignoresSafeArea()
                
                if let selection {
                    TaskContainerView(query: selection)
                        .environment(\.selectedScope, $selection)
                        .id(selection.id)
                        .frame(minWidth: 300)
                }
                else {
                    Text("No list selected")
                        .frame(minWidth: 300, maxWidth: .infinity)
                }
            }
            .taskCompleteButton(position: .leading)
            .environment(\.navigationSizeClass, .regular)
            
            // compact / mobile view
            
            Group {
                if let selection {
                    TaskContainerView(query: selection)
                        .environment(\.selectedScope, $selection)
                        .id(selection.id)
                        .transition(.move(edge: .trailing))
                }
                else {
                    ScopeListView(selectedScope: self.$selection)
                        .transition(.move(edge: .leading))
                }
            }
            .taskCompleteButton(position: .trailing)
            .environment(\.navigationSizeClass, .compact)
        }
        .animation(.snappy(duration: 0.3), value: self.selection)
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
                .fontWeight(.semibold)
        }
    }
}
