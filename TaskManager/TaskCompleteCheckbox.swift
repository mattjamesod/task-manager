import SwiftUI
import KillerModels
import KillerData

/// When checking the box, the view state is not updated. We simply make an async request to the DB
/// As a result of this request, we get a message to remove this task from the view, which we start to do
/// Then, hitting undo, we get another message telling us to add this task
///
/// Since in both instances of the view, completed\_at is nil, the view is not re-rendered... even though
/// the checkbox should now be unchecked

struct TaskCompleteCheckbox: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    @Environment(\.taskListMonitor) var taskListMonitor
    @Environment(\.tasksPending) var pending
    
    @ScaledMetric private var checkboxWidth: Double = 16
    @ScaledMetric private var checkboxBorderWidth: Double = 1.5
    
    @State private var isOn: Bool = false
    private var completedStyling: Bool { isOn && !pending }
    
    private let delay: Duration = .seconds(0.3)
    
    let task: KillerTask
    
    init(task: KillerTask) {
        self.task = task
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                        .strokeBorder(style: .init(
                            lineWidth: completedStyling ? 0 : self.checkboxBorderWidth,
                            dash: pending ? [2] : []
                        ))
                        .foregroundStyle(.gray)
                    
                    RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                        .foregroundStyle(completedStyling ? Color.accentColor : .clear)
                    
                    if completedStyling {
                        Image(systemName: "checkmark")
                            .resizable()
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(4)
                            .transition(.scale)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(width: self.checkboxWidth)
                .contentShape(Rectangle())
            }
        }
        .disabled(pending)
        .sensoryFeedback(.success, trigger: isOn)
        .animation(.snappy(duration: 0.1), value: isOn)
        .toggleStyle(.button)
        .onLocalChange(of: $isOn, source: task.isComplete, setupFromSource: true) {
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
