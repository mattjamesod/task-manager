import SwiftUI
import KillerStyle

public enum NavigationSizeClass {
    case regular
    case compact
}

public extension EnvironmentValues {
    @Entry var navigationSizeClass: NavigationSizeClass = .regular
}

public enum KillerNavigation {
    
}

extension KillerNavigation {
    struct NoContentView: View {
        public var body: some View {
            VStack(spacing: 8) {
                Text("Nothing Selected")
                    .font(.title)
                    .fontWeight(.bold)
                Text(String("¯\u{005C}_(ツ)_/¯"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.gray)
        }
    }
    
    struct SidebarEdgeGradient: View {
        @Environment(\.colorScheme) var colorScheme
        @Environment(\.layoutDirection) var layoutDirection
        
        public var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0),
                    Color(white: 0.95).opacity(0.3),
                    Color(white: 0.95),
                ]),
                startPoint: layoutDirection == .leftToRight ? .leading : .trailing,
                endPoint: layoutDirection == .leftToRight ? .trailing : .leading
            )
            .frame(width: 12)
            .ignoresSafeArea()
            .opacity(colorScheme == .light ? 1 : 0)
        }
    }
    
    struct SidebarContainerView<Content: View>: View {
        let content: () -> Content
        
        public var body: some View {
            HStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    content()
                    SidebarEdgeGradient()
                }
                .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
                
                Divider().ignoresSafeArea()
            }
        }
    }
}
