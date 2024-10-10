import SwiftUI
import UtilExtensions

enum NavigationSizeClass {
    case regular
    case compact
}

extension EnvironmentValues {
    @Entry var navigationSizeClass: NavigationSizeClass = .regular
}

struct ContainerPaddingViewModifier: ViewModifier {
    @Environment(\.navigationSizeClass) var navigationSizeClass
    
    let axis: Axis?
    
    private var padding: EdgeInsets {
        switch (axis, navigationSizeClass) {
            case (nil, .regular): EdgeInsets(vertical: 8, horizontal: 12)
            case (nil, .compact): EdgeInsets(vertical: 10, horizontal: 16)
            case (.horizontal, .regular): EdgeInsets(vertical: 0, horizontal: 12)
            case (.horizontal, .compact): EdgeInsets(vertical: 0, horizontal: 16)
            case (.vertical, .regular): EdgeInsets(vertical: 8, horizontal: 0)
            case (.vertical, .compact): EdgeInsets(vertical: 10, horizontal: 0)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .padding(self.padding)
    }
}

extension View {
    func containerPadding(axis: Axis? = nil) -> some View {
        self.modifier(ContainerPaddingViewModifier(axis: axis))
    }
}

struct KillerBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.accentColor)
            .containerPadding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(.ultraThinMaterial)
            }
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}

struct KillerInlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.accentColor)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}
