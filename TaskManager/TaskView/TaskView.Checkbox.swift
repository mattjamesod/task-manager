import SwiftUI
import KillerModels
import KillerData

/// When checking the box, the view state is not updated. We simply make an async request to the DB
/// As a result of this request, we get a message to remove this task from the view, which we start to do
/// Then, hitting undo, we get another message telling us to add this task
///
/// Since in both instances of the view, completed\_at is nil, the view is not re-rendered... even though
/// the checkbox should now be unchecked

extension TaskView {
    struct Checkbox: View {
        static let WIDTH: Double = 16
        static let BORDER_WIDTH: Double = 1.5
        
        @ScaledMetric private var checkboxWidth: Double = WIDTH
        @ScaledMetric private var checkboxBorderWidth: Double = BORDER_WIDTH
        
        @Environment(\.database) var database
        @Environment(\.contextQuery) var query
        
        @State private var isOn: Bool = false
        
        private let delay: Duration = .seconds(0.3)
        
        let task: KillerTask
        
        init(task: KillerTask) {
            self.task = task
            self._isOn = State(initialValue: task.isComplete)
        }
        
        var body: some View {
            Toggle(isOn: $isOn) {
                ZStack {
                    RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                        .strokeBorder(style: .init(
                            lineWidth: isOn ? 0 : self.checkboxBorderWidth
                        ))
                        .foregroundStyle(.gray)
                    
                    RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                        .foregroundStyle(isOn ? Color.accentColor : .clear)
                    
                    Image(systemName: "checkmark")
                        .resizable()
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(4)
                        .scaleEffect(isOn ? 1 : 0.5)
                        .opacity(isOn ? 1 : 0)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(width: self.checkboxWidth)
                .contentShape(Rectangle())
            }
            .sensoryFeedback(.success, trigger: isOn)
            .animation(.snappy(duration: 0.1), value: isOn)
            .toggleStyle(.button)
            .onLocalChange(of: $isOn, source: task.isComplete) {
                let isOn = self.isOn
                
                Task.detached {
                    try? await Task.sleep(for: self.delay)
                    
                    if isOn {
                        await database?.update(task, recursive: true, context: self.query, \.completedAt <- Date.now)
                    }
                    else {
                        await database?.update(task, recursive: true, context: self.query, \.completedAt <- nil)
                    }
                }
            }
        }
    }
}
