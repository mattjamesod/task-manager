import SwiftUI
import AsyncAlgorithms
import KillerModels
import KillerData

struct DebouncedTextField: View {
    @State var channel: AsyncChannel<String> = .init()
    
    @State var innerText: String
    @Binding var outerText: String
    
    let label: String
    let wait: Duration
    
    init(_ label: String, text: Binding<String>, wait: Duration = .seconds(0.5)) {
        self._innerText = State(initialValue: text.wrappedValue)
        self._outerText = text
        
        self.label = label
        self.wait = wait
    }
    
    var body: some View {
        TextField(label, text: $innerText)
            .onChange(of: innerText) {
                // onChange may execute on the main thread
                Task.detached {
                    await channel.send(innerText)
                }
            }
            .task {
                for await value in channel.debounce(for: self.wait) {
                    outerText = value
                }
            }
    }
}

struct TaskContainerView: View {
    @Environment(\.database) var database
        
    let taskListMonitor: QueryMonitor<TaskListViewModel> = .init()
    let orphanMonitor: QueryMonitor<TaskListViewModel> = .init()
    
    let query: Database.Query
    
    init(query: Database.Query) {
        self.query = query
    }
    
    @State var enteredText: String = ""
    
    var body: some View {
        ScrollView {
            TaskListView(.orphaned, monitor: orphanMonitor)
                .environment(\.taskListMonitor, self.taskListMonitor)
            
        }
        .defaultScrollAnchor(.center)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    NewTaskButton()
                    UndoButton()
                    RedoButton()
                }
                
                DebouncedTextField("New Task", text: $enteredText)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .padding(.horizontal, 16)
                    .onChange(of: enteredText) {
                        print(enteredText)
                    }
            }
            .padding(.bottom, 8)
        }
        .environment(\.contextQuery, self.query)
        .task {
            guard let database else { return }
            await taskListMonitor.beginMonitoring(query, on: database)
        }
        .task {
            guard let database else { return }
            await orphanMonitor.beginMonitoring(query.compose(with: .orphaned), recursive: true, on: database)
        }
        .onDisappear {
            Task.detached {
                await taskListMonitor.stopMonitoring()
                await orphanMonitor.stopMonitoring()
            }
        }
    }
}


extension EnvironmentValues {
    @Entry var taskListMonitor: QueryMonitor<TaskListViewModel>? = nil
    @Entry var contextQuery: Database.Query? = nil
}

struct NewTaskButton: View {
    @Environment(\.database) var database
    @Environment(\.contextQuery) var query
    
    var body: some View {
        Button("Add New Task") {
            Task.detached {
                let query = await self.query
                await database?.insert(KillerTask.self, \.body <- "A brand new baby task", context: query)//, \.parentID <- 4)
            }
        }
    }
}

struct UndoButton: View {
    @Environment(\.database) var database
    
    var body: some View {
        Button("Undo") {
            Task.detached {
                await database?.undo()
            }
        }
    }
}

struct RedoButton: View {
    @Environment(\.database) var database
    
    var body: some View {
        Button("Redo") {
            Task.detached {
                await database?.redo()
            }
        }
    }
}

extension Button {
    static func async(
        action: @Sendable @escaping () async -> Void,
        @ViewBuilder label: () -> Label
    ) -> Button<Label> {
        Button(action: { Task.detached { await action() }}, label: label)
    }
}
