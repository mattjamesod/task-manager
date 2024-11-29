#if canImport(UIKit)
import ObjectiveC
import UIKit
import UserNotifications
import CloudKit
import KillerData

class KillerAppDelegate: NSObject, UIApplicationDelegate {
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
        print("ping!")
//        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        let cloudDatabase = CKContainer(identifier: "iCloud.com.missingapostrophe.scopes").privateCloudDatabase
        let localDatabase = try! DatabaseSetupHelper(schema: .userData).setupDatabase()
        
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
