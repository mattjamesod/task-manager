import CloudKit

enum CloudKitSubscription {
    static var id: CKDatabaseSubscription.ID {
        "userDataChanges"
    }
    
    static var alreadySetup: Bool {
        setupDate != nil
    }
    
    static func registerSetup() {
        UserDefaults.standard.setValue(Date.now.timeIntervalSince1970, forKey: "cloudKitSubscriptionSetup")
    }
    
    static func build() -> CKDatabaseSubscription {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        
        let subscription = CKDatabaseSubscription(subscriptionID: self.id)
        subscription.notificationInfo = notificationInfo
        
        return subscription
    }
    
    private static var setupDate: Date? {
        guard let interval = UserDefaults.standard.dictionary(forKey: "cloudKitSubscriptionSetup") as? Double else {
            return nil
        }
        
        return Date(timeIntervalSince1970: interval)
    }
}
