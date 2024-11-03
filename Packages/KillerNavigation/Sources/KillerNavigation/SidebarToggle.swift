import SwiftUI

extension KillerNavigation {
    struct SidebarToggle: View {
        @State var isHovering: Bool = false
        @Binding var isVisible: Bool
        
        var body: some View {
            Toggle(isOn: $isVisible) {
                Label("Toggle Sidebar", systemImage: "inset.filled.leadingthird.rectangle")
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
