import SwiftUI
import UtilViews

#if canImport(UIKit)

public extension View {
    func shakeToUndo(on database: Database) -> some View {
        self.modifier(ShakeToUndoViewModifier(database: database))
    }
}

// TODO: why tf doesn't this work>??>
struct ShakeToUndoViewModifier: ViewModifier {
    @Environment(\.canUndo) var canUndo
    @State var showingAlert: Bool = false
    
    let database: Database
    
    init(database: Database) {
        self.database = database
    }
    
    func body(content: Content) -> some View {
        content
            .onShake {
                guard canUndo else { return }
                showingAlert = true
            }
            .alert("Undo?", isPresented: $showingAlert) {
                Button("Undo!") {
                    Task.detached {
                        await database.undo()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}

#endif
