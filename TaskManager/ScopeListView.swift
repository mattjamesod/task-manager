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
        private static var defaultScopeListWidth: Double = 330
        
        @Binding var selection: Database.Scope?
        
        @SceneStorage("scopeListVisibility") var scopeListVisibility: Bool = true
        @SceneStorage("scopeListWidth") var scopeListWidth: Double = Self.defaultScopeListWidth
        
        // this calculation means it's impossible to switch to compact view
        // through resizing the scope list view column
        private var taskContainerMinWidth: Double {
            400 + Self.defaultScopeListWidth - scopeListWidth
        }
        
        var body: some View {
            HStack(spacing: 0) {
                if scopeListVisibility {
                    HStack(spacing: 0) {
                        ScopeListView(selectedScope: self.$selection)
                            .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
                            .frame(width: self.scopeListWidth)
#if os(macOS)
                        ColumnResizeHandle(visible: $scopeListVisibility, width: $scopeListWidth)
#endif
                    }
                    .transition(.move(edge: .leading))
                }
                
                Group {
                    if let selection {
                        TaskContainerView(query: selection)
                            .environment(\.selectedScope, $selection)
                            .id(selection.id)
                            .overlay(alignment: .topLeading) {
                                Button {
                                    withAnimation {
                                        self.scopeListVisibility.toggle()
                                    }
                                } label: {
                                    Label("Toggle Scopes Column", systemImage: "sidebar.left")
                                        .labelStyle(.iconOnly)
                                        .font(.title3)
                                        .padding(.leading, 16)
                                }
                                .buttonStyle(KillerInlineButtonStyle())
                            }
                    }
                    else {
                        Text("No list selected")
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(minWidth: self.taskContainerMinWidth)
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

#if os(macOS)

struct ColumnResizeHandle: View {
    @Binding var visible: Bool
    @Binding var width: Double
    
    let minimum: Double = 150
    let maximum: Double = 400
    
    var body: some View {
        Rectangle()
            .frame(width: 15)
            .opacity(0)
            .contentShape(Rectangle())
            .pointerStyle(.columnResize)
            .gesture(DragGesture()
                .onChanged { gestureValue in
                    if width < maximum || gestureValue.translation.width <= 0 {
                        width = max(width + gestureValue.translation.width, minimum)
                    }
                }
                .onEnded { gestureValue in
                    if (width + gestureValue.translation.width) <= minimum {
                        withAnimation {
                            visible = false
                        }
                    }
                }
            )
            .offset(x: -7.5)
            .ignoresSafeArea()
    }
}

#endif

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
    
    @Namespace var namespace
    @Binding var selectedScope: Database.Scope?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(self.hardCodedScopes) { scope in
                    Button {
                        selectedScope = scope
                    } label: {
                        Label(scope.name, systemImage: scope.name == "Completed" ? "pencil" : "list.bullet.indent")
                            .labelStyle(ScopeListLabelStyle(
                                selected: scope == selectedScope,
                                animationNamespace: namespace
                            ))
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .safeAreaPadding(.top, 12)
        .safeAreaInset(edge: .top) {
            Text("Scopes")
                .fontWeight(.semibold)
        }
    }
}

struct ScopeListLabelStyle: LabelStyle {
    @ScaledMetric var iconWidth: Double = 12
    
    let selected: Bool
    let animationNamespace: Namespace.ID
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: self.iconWidth * 1.5) {
            configuration.icon
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .frame(width: self.iconWidth, alignment: .center)
            
            configuration.title
                .lineLimit(1)
        }
        .fadeOutScrollTransition()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.thickMaterial)
                    .matchedGeometryEffect(id: "ScopeListViewSelected", in: animationNamespace)
            }
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .animation(.interactiveSpring(duration: 0.1), value: self.selected)
    }
}
