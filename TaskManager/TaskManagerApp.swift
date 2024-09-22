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
                        //                    TaskContainerView(query: .allActiveTasks)
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
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .commandsRemoved()
        .defaultWindowPlacement { content, context in
            let displayBounds = context.defaultDisplay.bounds
            let contentSize = content.sizeThatFits(.unspecified)
            let position = CGPoint(
              x: displayBounds.midX - (contentSize.width / 2),
              y: displayBounds.midY - (contentSize.height / 2)
            )
            return WindowPlacement(position, size: contentSize)
          }
#endif
    }
}

struct AboutView: View {
    @GestureState var isDraggingWindow = false

    var dragWindow: some Gesture {
      WindowDragGesture()
        .updating($isDraggingWindow) { _, state, _ in
          state = true
        }
    }

    private let appVersion: String? = Bundle.main.releaseVersionNumber
    private let buildNumber: String? = Bundle.main.buildVersionNumber
    
    private var versionText: String {
        appVersion == nil ? "Unknown Version" : "Version \(appVersion!)"
    }
    
    private var buildText: String {
        buildNumber == nil ? "Unknown Build" : "Build \(buildNumber!)"
    }
    
    var body: some View {
        HStack {
            Rectangle()
                .foregroundStyle(.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .aspectRatio(1, contentMode: .fit)
                .frame(width: 64)
            
            VStack(alignment: .leading) {
                Text("Scopes")
                    .fontWeight(.bold)
                Text(versionText)
                Text(buildText)
            }
        }
        .ignoresSafeArea()
        .padding(24)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .foregroundStyle(.thickMaterial)
//                RoundedRectangle(cornerRadius: 9)
//                    .strokeBorder(.gray, lineWidth: 0.3)
            }
        }
        .gesture(dragWindow)
        .opacity(isDraggingWindow ? 0.8 : 1)
        .onChange(of: isDraggingWindow) {
          if isDraggingWindow {
            NSCursor.closedHand.push()
          } else {
            NSCursor.pop()
          }
        }
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
