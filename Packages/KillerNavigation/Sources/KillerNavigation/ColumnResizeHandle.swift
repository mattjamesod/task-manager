import SwiftUI

#if os(macOS)

extension KillerNavigation {
    struct ColumnResizeHandle: View {
        @Environment(\.layoutDirection) var layoutDirection
        
        @Binding var visible: Bool
        @Binding var width: Double
        
        let handleWidth: Double = 10
        
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
                        guard width < sidebarMaxWidth || translationWidth < 0 else { return }
                        guard width >= sidebarMinWidth || translationWidth > 0 else { return }
                        
                        // dragged off the edge of the window, collapse the column
                        if width + translationWidth < 0 {
                            withAnimation(.interactiveSpring(duration: 0.4)) { visible = false }
                        }
                        
                        width = max(width + translationWidth, sidebarMinWidth)
                    }
                )
                .ignoresSafeArea()
                .offset(x: -handleWidth / 2)
        }
    }
}

#endif
