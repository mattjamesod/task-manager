import SwiftUI
import UtilAlgorithms
import KillerModels
import KillerData

struct TaskContainerCountKey: PreferenceKey {
    static let defaultValue: Int = 0

    static func reduce(value: inout Int, nextValue: () -> Int) {
        value = value + nextValue()
    }
}

extension View {
    func taskContainerCount(_ count: Int) -> some View {
        self.preference(key: TaskContainerCountKey.self, value: count)
    }
}

@Observable @MainActor
final class TaskProvider: SynchronisedStateContainer {
    var tasks: [KillerTask] = []
    let filter: (KillerTask) -> Bool
    let sortOrder: (KillerTask, KillerTask) -> Bool
    
    init(
        filter: @escaping (KillerTask) -> Bool = { _ in true },
        sortOrder: @escaping (KillerTask, KillerTask) -> Bool = { $0.createdAt < $1.createdAt }
    ) {
        self.filter = filter
        self.sortOrder = sortOrder
    }
        
    func addOrUpdate(model: KillerTask) {
        guard filter(model) else { return }
        
        if let index = tasks.firstIndex(where: { $0.id == model.id }) {
            tasks[index] = model
        }
        else {
            tasks.insert(model, at: insertIndex(of: model))
        }
    }
    
    func addOrUpdate(models: [KillerTask]) {
        for model in models {
            addOrUpdate(model: model)
        }
    }
    
    func remove(with id: Int) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
    
    func remove(with ids: Set<Int>) {
        for id in ids {
            remove(with: id)
        }
    }
    
    private func insertIndex(of task: KillerTask) -> Int {
        self.tasks.binarySearch { self.sortOrder($0, task) }
    }
}
