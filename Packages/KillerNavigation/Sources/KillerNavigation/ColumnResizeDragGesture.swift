import SwiftUI

struct ColumnResizeDragGesture: Gesture {
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
