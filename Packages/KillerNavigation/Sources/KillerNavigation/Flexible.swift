import SwiftUI

public extension KillerNavigation {
    private static var flexibleBreakPoint: Double { sidebarContentMinWidth + sidebarMaxWidth }
    
    struct Flexible<Selection: Hashable & ProvidesNavigationHeader, SelectorView: View, ContentView: View>: View {
        @State var selectionCache: [Selection] = []
        
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
                    selectionCache: $selectionCache,
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
            .onChange(of: selection, initial: true) {
                guard let selection else { return }
                guard !selectionCache.contains(where: { $0 == selection }) else { return }
                self.selectionCache.append(selection)
            }
        }
    }
}
