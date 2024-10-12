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
                        .safeAreaPadding(.top, 12)
                        .safeAreaInset(edge: .top) {
                            Button {
                                self.pushed = nil
                            } label: {
                                Label("Back", systemImage: "chevron.backward")
                                    .labelStyle(.iconOnly)
                                    .fontWeight(.semibold)
                                    .containerPadding(axis: .horizontal)
                                    .contentShape(Rectangle())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .buttonStyle(KillerInlineButtonStyle())
                        }
                        .geometryGroup()
                        .transition(.move(edge: .trailing))
                }
            }
            .onEdgeSwipe { pushed = nil }
        }
        .animation(.interactiveSpring(duration: 0.4), value: pushed)
    }
}


struct KillerSidebarNavigation<Selection: Hashable, SelectorView: View, ContentView: View>: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var selection: Selection?
    
    let selectorView: (Binding<Selection?>) -> SelectorView
    let contentView: (Selection) -> ContentView
    
    @SceneStorage("sidebarVisibile") var sidebarVisibile: Bool = true
    @SceneStorage("sidebarWidth") var sidebarWidth: Double = 330
    
    // this calculation means it's impossible to switch to compact view
    // through resizing the sidebar
    private var contentMinWidth: Double {
        400 + 330 - sidebarWidth
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisibile {
                HStack(spacing: 0) {
                    ZStack(alignment: .trailing) {
                        selectorView($selection)
                        
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
                    .frame(width: self.sidebarWidth)
                    
                    Divider().ignoresSafeArea()
#if os(macOS)
                    ColumnResizeHandle(visible: $sidebarVisibile, width: $sidebarWidth)
#endif
                }
                .transition(.move(edge: .leading))
            }
            
            ZStack {
                if let selection {
                    contentView(selection)
                        .safeAreaPadding(.top, 12)
                        .safeAreaInset(edge: .top) {
                            Button {
                                withAnimation {
                                    self.sidebarVisibile.toggle()
                                }
                            } label: {
                                Label("Toggle Sidebar", systemImage: "sidebar.left")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                                    .padding(.leading, 16)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .buttonStyle(KillerInlineButtonStyle())
                        }
                }
                else {
                    Text("No list selected")
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(minWidth: self.contentMinWidth)
        }
    }
}
