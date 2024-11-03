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

extension KillerNavigation {
    struct SidebarToolbarToggle: View {
        @State var isHovering: Bool = false
        @Binding var isVisible: Bool
        
        var body: some View {
            Toggle(isOn: $isVisible) {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.ultraThickMaterial)
                            .brightness(isHovering ? -0.05 : 0)
                            .opacity(isVisible && !isHovering ? 0 : 1)
                    }
            }
            .labelStyle(.iconOnly)
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .keyboardShortcut(.init("0", modifiers: .command))
            .onHover { isHovering in
                self.isHovering = isHovering
            }
        }
    }
}

#endif
