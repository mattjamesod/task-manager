import SwiftUI

public protocol RecursiveData: Identifiable {
    var parentID: Self.ID? { get }
}
