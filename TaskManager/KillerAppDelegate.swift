import ObjectiveC
import CloudKit
import KillerData

#if canImport(UIKit)
import UIKit

class KillerAppDelegate: NSObject, UIApplicationDelegate {
    var cloudKitDownloadEngine: CloudKitDownloadEngine?
    
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
        guard let cloudKitDownloadEngine else { return }
        
//        let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
//        let engine = CloudKitDownloadEngine(cloud: cloudDatabase, local: localDatabase)
        
        Task {
            do {
                try await cloudKitDownloadEngine.downloadLatestChanges()
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
    var cloudKitDownloadEngine: CloudKitDownloadEngine?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.registerForRemoteNotifications()
    }
    
    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String : Any]
    ) {
        guard let cloudKitDownloadEngine else { return }
        
//        let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
//        let engine = CloudKitDownloadEngine(cloud: cloudDatabase, local: localDatabase)
        
        Task {
            do {
                try await cloudKitDownloadEngine.downloadLatestChanges()
            }
            catch {
                // TODO: log error
                print("failed to download CK changes from notification")
            }
        }
    }
}

#endif
