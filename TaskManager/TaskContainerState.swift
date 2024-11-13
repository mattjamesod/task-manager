import SwiftUI

enum TaskContainerState: Equatable {
    case loading
    case empty
    case done(itemCount: Int)
    
    var isDone: Bool {
        if case .done(_) = self { true } else { false }
    }
    
    static func combine(_ x: TaskContainerState, _ y: TaskContainerState) -> TaskContainerState {
        switch (x, y) {
            case (.empty, .empty): .empty
            case (.loading, _): .loading
            case (_, .loading): .loading
            case (.done, .empty): x
            case (.empty, .done): y
            case (.done(let cX), .done(let cY)): .done(itemCount: cX + cY)
        }
    }
}

struct TaskContainerStateKey: PreferenceKey {
    static let defaultValue: TaskContainerState = .empty

    static func reduce(value: inout TaskContainerState, nextValue: () -> TaskContainerState) {
        value = TaskContainerState.combine(value, nextValue())
    }
}

extension View {
    func taskListState(_ state: TaskContainerState) -> some View {
        self.preference(key: TaskContainerStateKey.self, value: state)
    }
}
