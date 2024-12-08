import SwiftUI
import KillerData
import CloudKit
import KillerNavigation
import UtilViews

@main
struct TaskManagerApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(KillerAppDelegate.self) var appDelegate
    #endif
    
    #if canImport(AppKit)
    @NSApplicationDelegateAdaptor(KillerAppDelegate.self) var appDelegate
    #endif
    
    let database: Database?
    // we store a reference to this monitor so it can receive CK-related events
    let cloudKitMonitor: Database.CloudKitUploadMonitor?
    
    init() {
        let helper = DatabaseSetupHelper(schema: .userData)
        
        do {
            let database = try helper.setupDatabase()
            
            self.database = database
            self.cloudKitMonitor = database.enableCloudkitUpload()
            
            appDelegate.cloudKitDownloadEngine = CloudKitDownloadEngine(database: database)
        }
        catch {
            // TODO: log database setup error
            self.database = nil
            self.cloudKitMonitor = nil
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

struct BijectionContainerViewModifier: ViewModifier {
    let database: Database?
    
    init(database: Database?) {
        self.database = database
    }
    
    func body(content: Content) -> some View {
        content
            #if canImport(UIKit)
            .shakeToUndo(on: database)
            #endif
    }
}

public extension View {
    func recordsBijections(on database: Database?) -> some View {
        self.modifier(BijectionContainerViewModifier(database: database))
    }
}

struct ScopeNavigationWindow: Scene {
    @Environment(\.openWindow) var openWindow
    
    @State var canUndo: Bool = false
    @State var canRedo: Bool = false
    
    let database: Database?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let database {
                    ScopeNavigation(selection: .allActiveTasks)
                        .mainWindowContent()
                        .recordsBijections(on: database)
                    // TODO: move this into recordsBijections, commands are hard
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
                        .environment(\.database, database)
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
