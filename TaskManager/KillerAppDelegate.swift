#if canImport(UIKit)
import ObjectiveC
import UIKit
import UserNotifications
import CloudKit
import KillerData

class KillerAppDelegate: NSObject, UIApplicationDelegate {
    var localDatabase: Database?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
//        application.registerForRemoteNotifications()
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
                completionHandler(.failed)
            }
        }
    }
}
#endif
