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
                .gesture(ColumnResizeDragGesture(isVisible: $isVisible, width: $width))
                .ignoresSafeArea()
                .offset(x: -handleWidth / 2)
        }
    }
}

#endif
