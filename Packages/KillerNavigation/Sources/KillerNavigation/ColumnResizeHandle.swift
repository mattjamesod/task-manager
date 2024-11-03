import SwiftUI

#if os(macOS)

extension KillerNavigation {
    struct ColumnResizeHandle: View {
        @Binding var isVisible: Bool
        @Binding var width: Double
        
        let handleWidth: Double = 10
        
        var body: some View {
            Rectangle()
                .frame(width: handleWidth)
                .opacity(0)
                .contentShape(Rectangle())
                .pointerStyle(isVisible ? .columnResize : .default)
                .gesture(SidebarResizeDragGesture(isVisible: $isVisible, width: $width))
                .ignoresSafeArea()
                .offset(x: -handleWidth / 2)
        }
    }
}

extension KillerNavigation {
    struct ColumnResizeHandleHead: View {
        @State var isHovering: Bool = false
        
        @Binding var isVisible: Bool
        @Binding var width: Double
        
        var body: some View {
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 8, height: 40)
                .foregroundStyle(.ultraThickMaterial)
                .brightness(isHovering ? 0.05 : 0)
                .padding(4)
                .contentShape(Rectangle())
                .pointerStyle(.columnResize)
                .gesture(SidebarResizeDragGesture(isVisible: $isVisible, width: $width))
                .onTapGesture {
                    isVisible.toggle()
                }
                .onHover { isHovering in
                    self.isHovering = isHovering
                }
        }
    }
}

#endif

struct SidebarResizeDragGesture: Gesture {
    @Environment(\.layoutDirection) var layoutDirection
    
    @Binding var isVisible: Bool
    @Binding var width: Double
    
    var maxWidth: Double { KillerNavigation.sidebarMaxWidth }
    var minWidth: Double { KillerNavigation.sidebarMinWidth }
    
    var body: some Gesture {
        DragGesture()
            .onChanged { gestureValue in
                let translationWidth =
                gestureValue.translation.width *
                (layoutDirection == .rightToLeft ? -1 : 1)
                
                guard isVisible else { return }
                guard width < maxWidth || translationWidth < 0 else { return }
                guard width >= minWidth || translationWidth > 0 else { return }
                
                // dragged off the edge of the window, collapse the column
                if width + translationWidth < 0 {
                    withAnimation(.interactiveSpring(duration: 0.4)) { isVisible = false }
                }
                
                width = max(width + translationWidth, minWidth)
            }
    }
}
