import CloudKit

enum CloudKitZone {
    case userData
    
    var name: String {
        switch self {
        case .userData: "User Data"
        }
    }
    
    var id: CKRecordZone.ID {
        CKRecordZone.ID.init(zoneName: self.name, ownerName: CKCurrentUserDefaultName)
    }
    
    var alreadySetup: Bool {
        CloudKitZone.setups[self.setupKey] != nil
    }
    
    func registerSetup() {
        var setups = CloudKitZone.setups
        setups[self.setupKey] = Date.now
        UserDefaults.standard.setValue(setups, forKey: "cloudKitZoneSetups")
    }
    
    private var setupKey: String {
        switch self {
        case .userData: "userData"
        }
    }
    
    private static var setups: [String: Date] {
        UserDefaults.standard.dictionary(forKey: "cloudKitZoneSetups") as? [String: Date] ?? [:]
    }
}
