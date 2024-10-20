import SwiftUI
import KillerData

enum KillerNavigation {
    static let sidebarDefaultWidth: Double = 330
    static var flexibleBreakPoint: Double { sidebarDefaultWidth + 250 }
}

extension KillerNavigation {
    struct Flexible<Selection: Hashable, SelectorView: View, ContentView: View>: View {
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
        var body: some View {
            ViewThatFits(in: .horizontal) {
                KillerNavigation.Sidebar(
                    selection: $selection,
                    selectorView: selectorView,
                    contentView: contentView
                )
                .frame(minWidth: KillerNavigation.flexibleBreakPoint)
                .environment(\.navigationSizeClass, .regular)
                
                KillerNavigation.Stack(
                    selection: $selection,
                    selectorView: selectorView,
                    contentView: contentView
                )
                .environment(\.navigationSizeClass, .compact)
            }
        }
    }
}

extension KillerNavigation {
    struct Stack<Selection: Hashable, SelectorView: View, ContentView: View>: View {
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
        var body: some View {
            ZStack {
                selectorView($selection)
                    .scaleEffect(selection != nil ? 0.95 : 1)
                    .backgroundFill(style: .ultraThinMaterial)
                    .brightness(selection != nil ? -0.05 : 0)
                
                // Group is weird here for unknown reasons, the animations don't play
                ZStack {
                    if let selection {
                        contentView(selection)
                            .backgroundFill()
                            .safeAreaPadding(.top, 12)
                            .safeAreaInset(edge: .top) {
                                self.backButton
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .buttonStyle(KillerInlineButtonStyle())
                            }
                            .geometryGroup()
                            .transition(.move(edge: .trailing))
                    }
                }
                .onEdgeSwipe { selection = nil }
            }
            .animation(.interactiveSpring(duration: 0.4), value: selection)
        }
        
        private var backButton: some View {
            Button {
                selection = nil
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
                    .containerPadding(axis: .horizontal)
            }
        }
    }
}

extension KillerNavigation {
    struct NoContentView: View {
        var body: some View {
            VStack(spacing: 8) {
                Text("Nothing Selected")
                    .font(.title)
                    .fontWeight(.bold)
                Text(String("¯\u{005C}_(ツ)_/¯"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.gray)
        }
    }
    
    struct SidebarEdgeGradient: View {
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.layoutDirection) var layoutDirection
        
        var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0),
                    Color(white: 0.95).opacity(0.3),
                    Color(white: 0.95),
                ]),
                startPoint: layoutDirection == .leftToRight ? .leading : .trailing,
                endPoint: layoutDirection == .leftToRight ? .trailing : .leading
            )
            .frame(width: 12)
            .ignoresSafeArea()
            .opacity(colorScheme == .light ? 1 : 0)
        }
    }
    
    struct SidebarContainerView<Content: View>: View {
        let content: () -> Content
        
        var body: some View {
            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    content()
                    SidebarEdgeGradient()
                }
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
                
                Divider().ignoresSafeArea()
            }
        }
    }
    
    struct Sidebar<Selection: Hashable, SelectorView: View, ContentView: View>: View {
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
        @SceneStorage("sidebarVisibile") var sidebarVisibile: Bool = true
        @SceneStorage("sidebarWidth") var sidebarWidth: Double = KillerNavigation.sidebarDefaultWidth
        
        var body: some View {
            HStack(spacing: 0) {
                if sidebarVisibile {
                    SidebarContainerView {
                        selectorView($selection)
                    }
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading))
                }
                
                ZStack {
                    if let selection {
                        contentView(selection)
                    }
                    else {
                        NoContentView()
                    }
                }
                .frame(minWidth: KillerNavigation.sidebarDefaultWidth)
                .safeAreaPadding(.top, 12)
                .safeAreaInset(edge: .top) {
                    Toggle(isOn: $sidebarVisibile) {
                        Label("Toggle Sidebar", systemImage: "sidebar.leading")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .toggleStyle(.button)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .buttonStyle(KillerInlineButtonStyle())
                }
            }
#if os(macOS)
            .overlay(alignment: .leading) {
                ColumnResizeHandle(visible: $sidebarVisibile, width: $sidebarWidth)
                    .offset(x: self.sidebarWidth)
            }
#endif
            .animation(.interactiveSpring(duration: 0.4), value: sidebarVisibile)
        }
    }
}

#if os(macOS)

struct ColumnResizeHandle: View {
    @Environment(\.layoutDirection) var layoutDirection
    
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
                    let translationWidth =
                        gestureValue.translation.width *
                        (layoutDirection == .rightToLeft ? -1 : 1)
                    
                    guard visible else { return }
                    guard width < maximum || translationWidth < 0 else { return }
                    guard width >= minimum  || translationWidth > 0 else { return }
                    
                    // dragged off the edge of the window, collapse the column
                    if width + translationWidth < 0 {
                        withAnimation(.interactiveSpring(duration: 0.4)) { visible = false }
                    }
                    
                    width = max(width + translationWidth, minimum)
                }
            )
//            .border(.red)
            .ignoresSafeArea()
            .offset(x: -handleWidth / 2)
    }
}

#endif
