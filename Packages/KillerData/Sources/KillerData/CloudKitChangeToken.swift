import Foundation
import CloudKit

struct CloudKitChangeToken {
    private let name: String
    
    init(named name: String = "CloudKitServerChangeToken") {
        self.name = name
    }
    
    func save(_ token: CKServerChangeToken?) throws {
        let tokenData = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        UserDefaults.standard.set(tokenData, forKey: self.name)
    }
    
    func fetch() throws -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: self.name) else {
            return nil
        }
        
        let token = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: CKServerChangeToken.self,
            from: data
        )
        
        return token
    }
    
}
