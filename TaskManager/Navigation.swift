import SwiftUI
import KillerData

struct KillerStackNavigation<Selection: Hashable, SelectorView: View, ContentView: View>: View {
    @Binding var pushed: Selection?
    
    let selectorView: (Binding<Selection?>) -> SelectorView
    let contentView: (Selection) -> ContentView
    
    var body: some View {
        ZStack {
            selectorView($pushed)
                .backgroundFill(style: .ultraThinMaterial)
            
            // Group is weird here for unknown reasons, the animations don't play
            ZStack {
                if let pushed {
                    contentView(pushed)
                        .backgroundFill()
                        .geometryGroup()
                        .transition(.move(edge: .trailing))
                }
            }
            .onEdgeSwipe { pushed = nil }
        }
        .animation(.interactiveSpring(duration: 0.4), value: pushed)
    }
}

struct ScopeCompactNavigation: View {
    @Binding var selection: Database.Scope?
    
    var body: some View {
        KillerStackNavigation(pushed: $selection) {
            ScopeListView(selectedScope: $0)
                .killerToolbar {
                    Text("Scopes")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
        } contentView: { selection in
            TaskContainerView(scope: selection)
                .id(selection.id)
                .killerToolbar {
                    Text(selection.name)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Button {
                        self.selection = nil
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.iconOnly)
                            .fontWeight(.semibold)
                            .containerPadding(axis: .horizontal)
                            .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
        }
    }
}

extension View {
    func killerToolbar(@ViewBuilder content: () -> some View) -> some View {
        self
            .safeAreaPadding(.top, 12)
            .safeAreaInset(edge: .top) {
                KillerToolbar(content: content)
            }
    }
}

struct KillerToolbar<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        ZStack {
            ForEach(subviews: content) { subView in
                subView
            }
        }
        .buttonStyle(KillerInlineButtonStyle())
    }
}
