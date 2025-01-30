import SwiftUI

@Observable @MainActor
final class Selection<T: Identifiable> {
    private(set) var ids: [T.ID] = []
    
    var chosen: T.ID? {
        ids.count == 1 ? ids.first! : nil
    }
    
    var last: T.ID? {
        ids.last
    }
    
    func choose(_ obj: T) {
        guard ids.first != obj.id else { return }
        chooseInvert(obj)
    }
    
    func chooseInvert(_ obj: T) {
        chooseInvert(id: obj.id)
    }
    
    func chooseInvert(id: T.ID?) {
        if id == nil {
            ids.removeAll()
        }
        else if let index = ids.firstIndex(of: id!) {
            ids.remove(at: index)
        }
        else {
            ids.removeAll()
            ids.append(id!)
        }
    }
    
    func remove(_ obj: T) {
        if let index = ids.firstIndex(of: obj.id) {
            ids.remove(at: index)
        }
    }
    
    func clear() {
        self.ids = []
    }
}
