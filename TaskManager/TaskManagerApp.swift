import SwiftUI
import KillerData
import KillerNavigation
import UtilViews

@main
struct TaskManagerApp: App {
    let database: Database?
    
    init() {
        do {
            self.database = try DatabaseSetupHelper(schema: .userData).setup()
        }
        catch {
            // TODO: log database setup error
            self.database = nil
        }
    }
        
    var body: some Scene {
        ScopeNavigationWindow(database: self.database)
#if os(macOS)
        AboutWindow()
        SettingsWindow()
#endif
    }
}

extension EnvironmentValues {
    @Entry var canUndo: Bool = false
    @Entry var canRedo: Bool = false
}


//enum SidebarStateMessage: Sendable {
//    case isVisible(Bool)
//    static let messenger: AsyncMessageHandler<Self> = .init()
//}

struct ScopeNavigationWindow: Scene {
    @Environment(\.openWindow) var openWindow
    
    @State var canUndo: Bool = false
    @State var canRedo: Bool = false
    
    @State var shakeUndoConfirm: Bool = false
    
    let database: Database?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let database {
                    ScopeNavigation(selection: .allActiveTasks)
                        .environment(\.database, database)
                        .mainWindowContent()
//                        .onKillerEvent(MutationHisoryMessage.self) { message in
//                            switch message {
//                            case .canUndo(let canUndo): self.canUndo = canUndo
//                            case .canRedo(let canRedo): self.canRedo = canRedo
//                            }
//                        }
                        .task {
                            let thread = await MutationHistory.messageHandler.subscribe()
                            
                            for await message in thread.events {
                                switch message {
                                case .canUndo(let canUndo): self.canUndo = canUndo
                                case .canRedo(let canRedo): self.canRedo = canRedo
                                }
                            }
                        }
                        .environment(\.canUndo, self.canUndo)
                        .environment(\.canRedo, self.canRedo)
                        .onShake {
                            guard canUndo else { return }
                            shakeUndoConfirm = true
                        }
                        .alert("Undo?", isPresented: $shakeUndoConfirm) {
                            Button("Undo!") {
                                Task.detached {
                                    await database.undo()
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                }
                else {
                    CatastrophicErrorView()
                        .mainWindowContent()
                }
            }
        }
//        .backgroundTask(.appRefresh("RECENTLY_DELETED_PURGE")) {
//            
//        }
#if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Scopes") {
                    openWindow(id: "about")
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(.init(","))
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    guard let database else { return }
                    
                    Task.detached {
                        await database.undo()
                    }
                }
                .disabled(!canUndo)
                .keyboardShortcut(.init("z"))
                
                Button("Redo") {
                    guard let database else { return }
                    
                    Task.detached {
                        await database.redo()
                    }
                }
                .disabled(!canRedo)
                .keyboardShortcut(.init("z", modifiers: [.command, .shift]))
            }
            CommandGroup(replacing: .sidebar) {
                Button("Show Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut(.init("0"))
            }
        }
#endif
    }
}

#if os(macOS)

struct SettingsWindow: Scene {
    var body: some Scene {
        Window("Settings", id: "settings") {
            Text("Settings")
                .frame(width: 600, height: 400)
                .fixedSize()
                .mainWindowContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
    }
}

#endif

struct CatastrophicErrorView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.red)
                .frame(maxWidth: 36)
            
            Text("An unexpected problem has occurred.")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)
            
            // TODO: add helpful links/info here
            
            Text("Please get in touch with support.")
                .foregroundStyle(.gray)
        }
    }
}

struct MainWindowContentViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.layoutDirection) var layoutDirection
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(TestingOverrides.colorScheme)
            .environment(\.layoutDirection, TestingOverrides.layoutDirecton ?? layoutDirection)
            .toolbar(removing: .title)
#if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .containerBackground(colorScheme.backgroundColor, for: .window)
            .onAppear { NSWindow.allowsAutomaticWindowTabbing = false }
#endif
    }
}

enum TestingOverrides {
    static let colorScheme: ColorScheme? = nil
    static let layoutDirecton: LayoutDirection? = nil
}

extension View {
    func mainWindowContent() -> some View {
        self
            .modifier(MainWindowContentViewModifier())
    }
}


#if canImport(UIKit)
// The notification we'll send when a shake gesture happens.
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

//  Override the default behavior of shake gestures to send our notification instead.
extension UIWindow {
     open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
     }
}

// A view modifier that detects shaking and calls a function of our choosing.
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

// A View extension to make the modifier easier to use.
extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}
#endif
