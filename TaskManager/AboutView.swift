import SwiftUI

#if os(macOS)

struct AboutWindow: Scene {
    var body: some Scene {
        Window("About Scopes", id: "about") {
            AboutView()
                .fixedSize()
                .mainWindowContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }
}

#endif

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
                     #if os(macOS)
                     .cursor(.pointingHand)
                     #endif
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
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        infoDictionary?["CFBundleVersion"] as? String
    }
}
