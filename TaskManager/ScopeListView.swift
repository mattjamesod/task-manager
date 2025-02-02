import SwiftUI
import KillerData
import KillerStyle
import KillerNavigation

extension EnvironmentValues {
    @Entry var selectedScope: Binding<Database.Scope?>?
}

struct ScopeNavigation: View {
    @Environment(\.database) var database
    @State var selection: Database.Scope?
    
    var body: some View {
        KillerNavigation.Flexible(
            selection: $selection,
            selectorView: ScopeListView.init,
            contentView: TaskScopeView.init
        )
        .taskCompleteButton(position: DeviceKind.current == .other ? .leading : .trailing)
    }
}

struct ScopeListView: View {
    let hardCodedScopes: [Database.Scope] = [
        .allActiveTasks,
        .completedTasks,
        .deletedTasks
    ]
    
    @Namespace private var namespace
    @Binding var selectedScope: Database.Scope?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Scopes")
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .fadeOutScrollTransition()
                    .containerPadding(axis: .horizontal)
                
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(self.hardCodedScopes) { scope in
                        Button {
                            selectedScope = scope
                        } label: {
                            Label(scope.name, systemImage: scope.symbolName)
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
                    .foregroundStyle(.ultraThickMaterial)
                    .matchedGeometryEffect(id: "ScopeListViewSelected", in: animationNamespace)
            }
        }
        .containerPadding(axis: .horizontal)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.05), value: self.selected)
    }
}
