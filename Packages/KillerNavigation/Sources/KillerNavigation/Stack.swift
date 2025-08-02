import SwiftUI
import KillerStyle

public extension KillerNavigation {
    struct Stack<Selection: Hashable & ProvidesNavigationHeader, SelectorView: View, ContentView: View>: View {
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
            ZStack {
                selectorView($selection)
                    .backgroundFill(style: .ultraThinMaterial)
                    .brightness(selection != nil ? -0.05 : 0)
                
                ZStack {
                    if let selection {
                        contentView(selection)
                            .backgroundFill()
                            .safeAreaInset(edge: .top) {
                                KillerNavigation.StackHeader(selection: $selection)
                            }
                            .geometryGroup()
                            .id(selection)
                            .opacity(selection == self.selection ? 1 : 0)
                            .onEdgeSwipe { self.selection = nil }
                            .transition(.move(edge: .trailing))
                    }
                }
            }
            .animation(.interactiveSpring(duration: 0.4), value: selection)
        }
    }
}
