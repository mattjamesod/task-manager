import Foundation
import AsyncAlgorithms
import Logging

protocol KillerSetting {
    static var key: String { get }
    static var defaultValue: Self { get }
    static var updates: AsyncChannel<Self> { get }
    static func fetch() -> Self
    
    func save()
    var value: String { get }
}

//extension KillerSetting {
//    func save() {
//        UserDefaults.standard.setValue(self.value, forKey: Self.key)
//        Task {
//            await Self.updates.send(self)
//        }
//    }
//}
