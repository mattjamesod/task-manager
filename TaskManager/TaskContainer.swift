import SwiftUI
import UtilAlgorithms
import KillerModels
import KillerData

extension Optional where Wrapped: Comparable {
    func lessThan(_ other: Wrapped?) -> Bool {
        switch (self == nil, other == nil) {
            case (_, true): return true
            case (true, _): return false
            case (false, false): return self! < other!
        }
    }
}

@Observable @MainActor
final class TaskContainer: SynchronisedStateContainer {
    var tasks: [KillerTask] = []
    let filter: (KillerTask) -> Bool
    let sortOrder: (KillerTask, KillerTask) -> Bool
    
    init(
        filter: @escaping (KillerTask) -> Bool = { _ in true },
        sortOrder: @escaping (KillerTask, KillerTask) -> Bool = { $0.createdAt.lessThan($1.createdAt) }
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
    
    func remove(with id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks.remove(at: index)
    }
    
    func remove(with ids: Set<UUID>) {
        for id in ids {
            remove(with: id)
        }
    }
    
    func appendOrRemovePendingTask(_ pendingTask: KillerTask?) {
        if let pendingTask {
            self.tasks.append(pendingTask)
        }
//        else {
//            guard self.tasks.count > 0 else { return }
//            self.tasks.removeLast()
//        }
    }
    
    private func insertIndex(of task: KillerTask) -> Int {
        self.tasks.binarySearch { self.sortOrder($0, task) }
    }
}
