import SwiftUI
import KillerData

struct ScopeCompactNavigation: View {
    @GestureState private var dragAmount: Double = 0
    
    @Binding var selection: Database.Scope?
    
    var body: some View {
        ZStack {
            ScopeListView(selectedScope: self.$selection)
                .safeAreaPadding(.top, 12)
                .safeAreaInset(edge: .top) {
                    Text("Scopes")
                        .fontWeight(.semibold)
                }
                .backgroundFill(style: .ultraThinMaterial)
            
            ZStack {
                if let selection {
                    TaskContainerView(scope: selection)
                        .backgroundFill()
                        .id(selection.id)
                        .safeAreaPadding(.top, 12)
                        .safeAreaInset(edge: .top) {
                            ZStack {
                                Text(selection.name)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                Button {
                                    self.selection = nil
                                } label: {
                                    Label("Back", systemImage: "chevron.backward")
                                        .labelStyle(.iconOnly)
                                        .fontWeight(.semibold)
                                        .containerPadding(axis: .horizontal)
                                        .contentShape(Rectangle())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .buttonStyle(KillerInlineButtonStyle())
                            }
                        }
                        .geometryGroup()
                        .transition(.move(edge: .trailing))
                }
            }
            .onEdgeSwipe { selection = nil }
        }
        .animation(.interactiveSpring(duration: 0.4), value: selection)
    }
}

struct EdgeSwipeViewModifier: ViewModifier {
    @Environment(\.layoutDirection) var layoutDirection
    
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
