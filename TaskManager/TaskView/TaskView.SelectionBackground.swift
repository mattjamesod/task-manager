import SwiftUI
import KillerModels

extension TaskView {
    struct SelectionBackground: View {
        @Environment(Selection<KillerTask>.self) var selection
        let task: KillerTask
        
        var body: some View {
            ZStack {
                Rectangle()
                    .foregroundStyle(Color.clear)
                if selection.ids.contains(task.id) {
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundStyle(.ultraThinMaterial)
                }
            }
        }
    }
}
