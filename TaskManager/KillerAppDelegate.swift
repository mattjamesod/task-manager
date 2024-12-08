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
        
        guard let cloudKitDownloadEngine else { return true }
        
        Task {
            do {
                try await cloudKitDownloadEngine.downloadLatestChanges()
            }
            catch {
                // TODO: log error
            }
        }
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let cloudKitDownloadEngine else {
            print("failed to download CK changes from notification")
            completionHandler(.failed)
            return
        }
        
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
    
    private func downloadCloudKitChanges(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let cloudKitDownloadEngine else { completionHandler(.failed); return }
        
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
        
        guard let cloudKitDownloadEngine else { return }
        
        Task {
            do {
                try await cloudKitDownloadEngine.downloadLatestChanges()
            }
            catch {
                // TODO: log error
            }
        }
    }
    
    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String : Any]
    ) {
        guard let cloudKitDownloadEngine else { return }
        
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
