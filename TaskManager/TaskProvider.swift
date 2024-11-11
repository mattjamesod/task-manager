import SwiftUI
import UtilAlgorithms
import KillerModels
import KillerData

// TODO: Mutating observable property \TaskProvider.tasks after view is torn down has no effect

@Observable @MainActor
final class TaskProvider: SynchronisedStateContainer {
    let isOrphan: Bool
    
    var tasks: [KillerTask] = []
    let filter: (KillerTask) -> Bool
    let sortOrder: (KillerTask, KillerTask) -> Bool
    
    init(
        filter: @escaping (KillerTask) -> Bool = { _ in true },
        sortOrder: @escaping (KillerTask, KillerTask) -> Bool = { $0.createdAt < $1.createdAt }, isOrphan: Bool
    ) {
        self.filter = filter
        self.sortOrder = sortOrder
        self.isOrphan = isOrphan
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
        print("\(isOrphan) - removing \(id) from \(tasks.map(\.id))")
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        print(index)
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
