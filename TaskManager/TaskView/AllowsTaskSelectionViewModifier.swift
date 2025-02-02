import SwiftUI
import KillerModels

struct AllowsTaskSelectionViewModifier: ViewModifier {
    @Environment(Selection<KillerTask>.self) var selection
    @FocusState var isFocused: Bool
    
    init(task: KillerTask) {
        self.task = task
    }
    
    let task: KillerTask
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onTapGesture {
                isFocused = true
                selection.choose(self.task)
            }
    }
}

extension View {
    func allowsTaskSelection(of task: KillerTask) -> some View {
        self.modifier(AllowsTaskSelectionViewModifier(task: task))
    }
}
