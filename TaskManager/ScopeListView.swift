import SwiftUI
import KillerData

extension EnvironmentValues {
    @Entry var selectedScope: Binding<Database.Scope?>?
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
        .geometryGroup()
    }
    
    struct Regular: View {
        @Environment(\.colorScheme) var colorScheme
        
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
                        ZStack(alignment: .trailing) {
                            ScopeListView(selectedScope: self.$selection)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0),
                                    Color(white: 0.95).opacity(0.3),
                                    Color(white: 0.95),
                                ]),
                                startPoint: .leading, endPoint: .trailing
                            )
                            .frame(width: 12)
                            .ignoresSafeArea()
                            .opacity(colorScheme == .light ? 1 : 0)
                        }
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
        @State var drag: Double = 0
        
        @Binding var selection: Database.Scope?
        
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            ZStack {
                ZStack {
                    ScopeListView(selectedScope: self.$selection)
                        .backgroundFill(style: .ultraThinMaterial)
                }
                ZStack {
                    if let selection {
                        TaskContainerView(query: selection)
                            .environment(\.selectedScope, $selection)
                            .backgroundFill()
                            .id(selection.id)
                            .geometryGroup()
                            .transition(.move(edge: .trailing))
                    }
                }
                .offset(x: self.drag)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.startLocation.x < 100 {
                                self.drag = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            if gesture.translation.width > 100 {
                                self.selection = nil
                            }
                            
                            withAnimation {
                                self.drag = 0
                            }
                        }
                )
            }
            .animation(.interactiveSpring(duration: 0.4), value: selection)
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
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
                    .containerPadding(axis: .horizontal)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    @ScaledMetric private var iconWidth: Double = 12
    @ScaledMetric private var spacing: Double = 18
    
    let selected: Bool
    let animationNamespace: Namespace.ID
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: self.spacing) {
            configuration.icon
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .frame(width: self.iconWidth, alignment: .center)
            
            configuration.title
                .lineLimit(1)
        }
        .fadeOutScrollTransition()
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerPadding()
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.thickMaterial)
                    .matchedGeometryEffect(id: "ScopeListViewSelected", in: animationNamespace)
            }
        }
        .containerPadding(axis: .horizontal)
        .contentShape(Rectangle())
        .animation(.interactiveSpring(duration: 0.1), value: self.selected)
    }
}
