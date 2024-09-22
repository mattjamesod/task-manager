import SwiftUI
import KillerData

@main
struct TaskManagerApp: App {
    
    @Environment(\.openWindow) var openWindow
    
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
        WindowGroup {
            Group {
                if let database {
                    VStack(spacing: 0) {
                        ScopeNavigation()
//                        TaskContainerView(query: .allActiveTasks)
                            .environment(\.database, database)
                    }
                }
                else {
                    CatastrophicErrorView()
                }
            }
            .toolbar(removing: .title)
#if os(macOS)
            .toolbarBackground(.hidden, for: .windowToolbar)
            .containerBackground(.white, for: .window)
#endif
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Scopes") {
                    openWindow(id: "about")
                }
            }
        }
//        .backgroundTask(.appRefresh("RECENTLY_DELETED_PURGE")) {
//
//        }
        
#if os(macOS)
        Window("About Scopes", id: "about") {
            AboutView()
                .fixedSize()
                .containerBackground(.white, for: .window)
        }
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
//        .restorationBehavior(.disabled)
        .commandsRemoved()
#endif
    }
}

struct AboutView: View {
    private let appVersion: String? = Bundle.main.releaseVersionNumber
    private let buildNumber: String? = Bundle.main.buildVersionNumber
    
    private var versionText: String {
        appVersion == nil ? "Unknown Version" : "Version \(appVersion!)"
    }
    
    private var buildText: String {
        buildNumber == nil ? "Unknown Build" : "\(buildNumber!)"
    }
    
    var body: some View {
        HStack(spacing: 24) {
            Rectangle()
                .foregroundStyle(.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 128)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Scopes")
                    .font(.title)
                    .fontWeight(.semibold)
                VStack(alignment: .leading) {
                    Text(versionText + " (\(buildText))")
                        .foregroundStyle(.gray)
                }
                
                 HStack(spacing: 0) {
                     Text("© 2024 ")
                     Link(destination: URL(string: "https://andhash39.com")!) {
                         Text("Matthew James O'Donnell")
                             .underline()
                             .foregroundStyle(.blue)
                     }
                     .cursor(.pointingHand)
                 }
                 .foregroundStyle(.gray)
            }
        }
        .ignoresSafeArea()
        .padding(48)
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

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

extension View {
    public func cursor(_ cursor: NSCursor) -> some View {
        if #available(macOS 13.0, *) {
            return self.onContinuousHover { phase in
                switch phase {
                case .active(_):
                    guard NSCursor.current != cursor else { return }
                    cursor.push()
                case .ended:
                    NSCursor.pop()
                }
            }
        } else {
            return self.onHover { inside in
                if inside {
                    cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}
