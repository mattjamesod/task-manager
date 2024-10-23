import SwiftUI
import KillerStyle

public extension KillerNavigation {
    struct Stack<Selection: Hashable, SelectorView: View, ContentView: View>: View {
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
