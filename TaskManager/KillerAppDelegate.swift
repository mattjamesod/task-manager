import ObjectiveC
import CloudKit
import KillerData

#if canImport(UIKit)
import UIKit

class KillerAppDelegate: NSObject, UIApplicationDelegate {
    var localDatabase: Database?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let localDatabase else { return }
        
        let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
        
        Task {
            do {
                let engine = CloudKitDownloadEngine(cloud: cloudDatabase, local: localDatabase)
                try await engine.downloadLatestChanges()
                completionHandler(.newData)
            }
            catch {
                // TODO: log error
                print("failed to download CK changes from notification")
                completionHandler(.failed)
            }
        }
    }
}
#endif

#if canImport(AppKit)
import AppKit

class KillerAppDelegate: NSObject, NSApplicationDelegate {
    var localDatabase: Database?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.registerForRemoteNotifications()
    }
    
    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String : Any]
    ) {
        guard let localDatabase else { return }
        
        let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
        
        Task {
            do {
                let engine = CloudKitDownloadEngine(cloud: cloudDatabase, local: localDatabase)
                try await engine.downloadLatestChanges()
            }
            catch {
                // TODO: log error
                print("failed to download CK changes from notification")
            }
        }
    }
}

#endif
