import SwiftUI
import KillerStyle

public extension KillerNavigation {
    static let sidebarDefaultWidth: Double = 280
    static let sidebarMinWidth: Double = 150
    static let sidebarMaxWidth: Double = 280
    
    static let sidebarContentMinWidth: Double = 220
    
    struct Sidebar<Selection: Hashable, SelectorView: View, ContentView: View>: View {
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
        @SceneStorage("sidebarVisibile") var sidebarVisibile: Bool = true
        @SceneStorage("sidebarWidth") var sidebarWidth: Double = KillerNavigation.sidebarDefaultWidth
        
        public init(
            selection: Binding<Selection?>,
            selectorView: @escaping (Binding<Selection?>) -> SelectorView,
            contentView: @escaping (Selection) -> ContentView
        ) {
            self._selection = selection
            self.selectorView = selectorView
            self.contentView = contentView
        }
        
        public var body: some View {
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
                .frame(minWidth: KillerNavigation.sidebarContentMinWidth)
            }
#if os(macOS)
            .overlay(alignment: .leading) {
                ColumnResizeHandle(isVisible: $sidebarVisibile, width: $sidebarWidth)
                    .offset(x: self.sidebarWidth)
            }
            .toolbar {
                SidebarToolbarToggle(isVisible: $sidebarVisibile, width: $sidebarWidth)
            }
#endif
            .animation(.interactiveSpring(duration: 0.4), value: sidebarVisibile)
        }
        
        private var toggle: some View {
            Toggle(isOn: $sidebarVisibile) {
                Label("Toggle Sidebar", systemImage: "sidebar.leading")
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .toggleStyle(.button)
        }
    }
}
