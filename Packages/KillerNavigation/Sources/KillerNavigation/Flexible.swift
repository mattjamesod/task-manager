import SwiftUI

public extension KillerNavigation {
    private static var flexibleBreakPoint: Double { sidebarContentMinWidth + sidebarMaxWidth }
    
    struct Flexible<Selection: Hashable, SelectorView: View, ContentView: View>: View {
        @Binding var selection: Selection?
        
        let selectorView: (Binding<Selection?>) -> SelectorView
        let contentView: (Selection) -> ContentView
        
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
            ViewThatFits(in: .horizontal) {
                KillerNavigation.Sidebar(
                    selection: $selection,
                    selectorView: selectorView,
                    contentView: contentView
                )
                .environment(\.navigationSizeClass, .regular)
                .frame(minWidth: KillerNavigation.flexibleBreakPoint)
                
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
