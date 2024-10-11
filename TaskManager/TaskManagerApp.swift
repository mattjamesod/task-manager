import SwiftUI
import KillerData
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


struct ScopeNavigationWindow: Scene {
    @Environment(\.openWindow) var openWindow
    
    let database: Database?
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let database {
                    ScopeNavigation(selection: .allActiveTasks)
                        .environment(\.database, database)
                        .mainWindowContent()
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
        }
#endif
    }
}

#if os(macOS)

struct SettingsWindow: Scene {
    var body: some Scene {
        Window("Settinsg", id: "settings") {
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
        VStack(spacing: 36) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .foregroundStyle(.red)
                .frame(maxWidth: 72)
            
            Text("An unexpected problem has occurred")
                .font(.title3)
                .foregroundStyle(.gray)
            
            // TODO: add helpful links/info here
        }
    }
}

struct MainWindowContentViewModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(TestingOverrides.colorScheme)
            .toolbar(removing: .title)
#if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .containerBackground(colorScheme.backgroundColor, for: .window)
#endif
    }
}

enum TestingOverrides {
    static let colorScheme: ColorScheme? = nil
}

extension View {
    func mainWindowContent() -> some View {
        self
            .modifier(MainWindowContentViewModifier())
    }
}
