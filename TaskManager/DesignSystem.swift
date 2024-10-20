import SwiftUI
import UtilExtensions

// On RTL localisation
//
// It makes sense to me that in RTL languages, the swipe should come from
// the RHS of the screen. However, this is hard to implement since CGPoint uses
// absolute x, y coords not leading/trailing.
//
// Basic tests show that apple's navigation stack doesn't do this either, so fuck it

// TODO: make this into a generic swipe gesture modifier

struct EdgeSwipeViewModifier: ViewModifier {
    @State private var dragAmount: Double = 0
    
    // need a starting threshold and a success threshold in future...
    private let threshold: Double = 80
    private let onSuccess: () -> ()
    
    init(onSuccess: @escaping () -> ()) {
        self.onSuccess = onSuccess
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragAmount)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        guard gesture.startLocation.x < threshold else { return }
                        dragAmount = max(0, gesture.translation.width)
                    }
                    .onEnded { gesture in
                        if gesture.translation.width > threshold { onSuccess() }
                        withAnimation(.interactiveSpring(duration: 0.4)) { dragAmount = 0 }
                    }
            )
    }
}

extension View {
    func onEdgeSwipe(onSuccess: @escaping () -> ()) -> some View {
        self.modifier(EdgeSwipeViewModifier(onSuccess: onSuccess))
    }
}

enum NavigationSizeClass {
    case regular
    case compact
}

extension EnvironmentValues {
    @Entry var navigationSizeClass: NavigationSizeClass = .regular
}

struct ContainerPaddingViewModifier: ViewModifier {
    let deviceKind = DeviceKind.current
    let axis: Axis?
    
    private var padding: EdgeInsets {
        switch (axis, deviceKind) {
            case (nil, .other): EdgeInsets(vertical: 8, horizontal: 12)
            case (nil, _): EdgeInsets(vertical: 10, horizontal: 16)
            case (.horizontal, .other): EdgeInsets(vertical: 0, horizontal: 12)
            case (.horizontal, _): EdgeInsets(vertical: 0, horizontal: 16)
            case (.vertical, .other): EdgeInsets(vertical: 8, horizontal: 0)
            case (.vertical, _): EdgeInsets(vertical: 10, horizontal: 0)
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

struct BackgroundFillViewModifier<StyleType: ShapeStyle>: ViewModifier {
    let style: StyleType
    
    init(_ style: StyleType) {
        self.style = style
    }
    
    func body(content: Content) -> some View {
        ZStack {
            Rectangle()
                .foregroundStyle(style)
                .ignoresSafeArea()
            
            content
        }
    }
}

struct DefaultBackgroundFillViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content.modifier(BackgroundFillViewModifier(colorScheme.backgroundColor))
    }
}

extension View {
    func backgroundFill() -> some View {
        self.modifier(DefaultBackgroundFillViewModifier())
    }
    
    func backgroundFill<StyleType: ShapeStyle>(style: StyleType) -> some View {
        self.modifier(BackgroundFillViewModifier(style))
    }
}

@MainActor
extension ColorScheme {
    var backgroundColor: Color {
        self == .dark ?
            (DeviceKind.current.isMobile ? Color.black : Color(white: 0.1)) :
            Color.white
    }
}

@MainActor
enum DeviceKind {
    case phone
    case pad
    case other
    
    var isMobile: Bool {
        [ .phone, .pad ].contains(self)
    }
    
    static var current: Self {
#if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ?
            .phone :
            .pad
#else
        .other
#endif
    }
}
