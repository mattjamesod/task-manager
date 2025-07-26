import SwiftUI
import KillerStyle

public extension KillerNavigation {
    static let sidebarDefaultWidth: Double = 280
    static let sidebarMinWidth: Double = 150
    static let sidebarMaxWidth: Double = 280
    
    static let sidebarContentMinWidth: Double = 220
    
    struct Sidebar<Selection: Hashable, SelectorView: View, ContentView: View>: View {
#if os(macOS)
        @Environment(\.appearsActive) var appearsActive
#endif
        
        @Binding var selectionCache: [Selection]
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
        @SceneStorage("sidebarVisible") var sidebarVisible: Bool = true
        @SceneStorage("sidebarWidth") var sidebarWidth: Double = KillerNavigation.sidebarDefaultWidth
        
        public init(
            selection: Binding<Selection?>,
            selectionCache: Binding<[Selection]>,
            selectorView: @escaping (Binding<Selection?>) -> SelectorView,
            contentView: @escaping (Selection) -> ContentView
        ) {
            self._selection = selection
            self._selectionCache = selectionCache
            self.selectorView = selectorView
            self.contentView = contentView
        }
        
        public var body: some View {
            HStack(spacing: 0) {
                if sidebarVisible {
                    SidebarContainerView {
                        selectorView($selection)
                    }
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading))
                }
                
                ZStack {
                    if let selection {
                        contentView(selection)
                            .id(selection)
                    }
                    else {
                        ZStack {
                            Rectangle()
                                .foregroundStyle(.thickMaterial)
                                .ignoresSafeArea()
                            Text("Please select from the sidebar.")
                                .fontWeight(.semibold)
                        }
                    }
//                    ForEach(selectionCache, id: \.hashValue) { selection in
//                        contentView(selection)
//                            .id(selection)
//                            .opacity(selection == self.selection ? 1 : 0)
//                    }
                }
                .frame(minWidth: KillerNavigation.sidebarContentMinWidth)
            }
#if os(macOS)
            .overlay(alignment: .leading) {
                ColumnResizeHandle(isVisible: $sidebarVisible, width: $sidebarWidth)
                    .offset(x: self.sidebarWidth)
            }
            .toolbar {
                SidebarToggle(isVisible: $sidebarVisible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                guard appearsActive else { return }
                sidebarVisible.toggle()
            }
#endif
            .animation(.interactiveSpring(duration: 0.4), value: sidebarVisible)
        }
    }
}

public extension Notification.Name {
    static let toggleSidebar = Notification.Name("toggleSidebar")
}
