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

struct ScopeNavigation: View {
    @State var selection: Database.Scope?
    
    var body: some View {
        ViewThatFits(in: .horizontal) {
            ScopeNavigation.Regular(selection: $selection)
                .taskCompleteButton(position: .leading)
                .environment(\.navigationSizeClass, .regular)
                        
            ScopeNavigation.Compact(selection: $selection)
                .taskCompleteButton(position: .trailing)
                .environment(\.navigationSizeClass, .compact)
        }
        .animation(.snappy(duration: 0.3), value: self.selection)
    }
    
    struct Regular: View {
        @Binding var selection: Database.Scope?
        
        var body: some View {
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
        }
    }
    
    struct Compact: View {
        @Binding var selection: Database.Scope?
        
        var body: some View {
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
        }
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(self.hardCodedScopes) { scope in
                    Button {
                        selectedScope = scope
                    } label: {
                        Label(scope.name, systemImage: scope.name == "Completed" ? "pencil" : "list.bullet.indent")
                            .labelStyle(ScopeListLabelStyle(selected: scope == selectedScope))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .safeAreaInset(edge: .top) {
            Text("Scopes")
                .fontWeight(.semibold)
        }
    }
}

struct ScopeListLabelStyle: LabelStyle {
    @ScaledMetric var iconWidth: Double = 12
    let selected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: self.iconWidth) {
            configuration.icon
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .frame(width: self.iconWidth, alignment: .center)
            
            configuration.title
        }
        .fadeOutScrollTransition()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.thickMaterial)
                .opacity(selected ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}
