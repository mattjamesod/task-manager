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
        @Binding var selection: Database.Scope?
        
        var body: some View {
            KillerSidebarNavigation(selection: $selection) { selection in
                ScopeListView(selectedScope: selection)
            } contentView: { selection in
            	TaskContainerView(scope: selection)
            	    .id(selection.id)
            }
        }
    }
    
    struct Compact: View {
        @Binding var selection: Database.Scope?
        
        var body: some View {
            KillerStackNavigation(pushed: $selection) { selection in
                ScopeListView(selectedScope: selection)
            } contentView: { selection in
                TaskContainerView(scope: selection)
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
