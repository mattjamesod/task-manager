import SwiftUI
import KillerData

struct DynamicNavigation<Selection: Hashable, SelectorView: View, ContentView: View>: View {
    
    @Binding var selection: Selection?
    
    let selectorView: (Binding<Selection?>) -> SelectorView
    let contentView: (Selection) -> ContentView

    var body: some View {
        ViewThatFits(in: .horizontal) {
            KillerSidebarNavigation(
                selection: $selection,
                selectorView: selectorView,
                contentView: contentView
            )
            .environment(\.navigationSizeClass, .regular)
            .taskCompleteButton(position: .leading)
            
            KillerStackNavigation(
                selection: $selection,
                selectorView: selectorView,
                contentView: contentView
            )
            .environment(\.navigationSizeClass, .compact)
            .taskCompleteButton(position: .trailing)
        }
    }
}


struct KillerStackNavigation<Selection: Hashable, SelectorView: View, ContentView: View>: View {
    @Binding var selection: Selection?
    
    let selectorView: (Binding<Selection?>) -> SelectorView
    let contentView: (Selection) -> ContentView
    
    var body: some View {
        ZStack {
            selectorView($selection)
                .backgroundFill(style: .ultraThinMaterial)
            
            // Group is weird here for unknown reasons, the animations don't play
            ZStack {
                if let selection {
                    contentView(selection)
                        .backgroundFill()
                        .safeAreaPadding(.top, 12)
                        .safeAreaInset(edge: .top) {
                            ZStack {
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
                                .buttonStyle(KillerInlineButtonStyle())
                            }
                        }
                        .geometryGroup()
                        .transition(.move(edge: .trailing))
                }
            }
            .onEdgeSwipe { selection = nil }
        }
        .animation(.interactiveSpring(duration: 0.4), value: selection)
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
        250 + 330 - sidebarWidth
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
                }
                else {
                    VStack(spacing: 8) {
                        Text("Nothing Selected")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(String("¯\u{005C}_(ツ)_/¯"))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.gray)
                }
            }
            .frame(minWidth: self.contentMinWidth, maxHeight: .infinity)
            .safeAreaInset(edge: .top) {
                Button {
                    withAnimation {
                        self.sidebarVisibile.toggle()
                    }
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.leading")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.leading, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(KillerInlineButtonStyle())
            }
        }
    }
}

#if os(macOS)

struct ColumnResizeHandle: View {
    @Binding var visible: Bool
    @Binding var width: Double
    
    let handleWidth: Double = 10
    
    let minimum: Double = 150
    let maximum: Double = 400
    
    var body: some View {
        Rectangle()
            .frame(width: handleWidth)
            .opacity(0)
            .contentShape(Rectangle())
            .pointerStyle(visible ? .columnResize : .default)
            .gesture(DragGesture()
                .onChanged { gestureValue in
                    guard visible else { return }
                    guard width < maximum || gestureValue.translation.width < 0 else { return }
                    guard width >= minimum  || gestureValue.translation.width > 0 else { return }
                    
                    // dragged off the edge of the window, collapse the column
                    if width + gestureValue.translation.width < 0 {
                        withAnimation(.interactiveSpring(duration: 0.4)) { visible = false }
                    }
                    
                    width = max(width + gestureValue.translation.width, minimum)
                }
            )
            .offset(x: -handleWidth / 2)
            .ignoresSafeArea()
    }
}

#endif
