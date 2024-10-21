import SwiftUI

public extension EdgeInsets {
    init(vertical: Double, horizontal: Double) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
    
    var horizontalTotal: Double {
        self.leading + self.trailing
    }
    
    var verticalTotal: Double {
        self.top + self.bottom
    }
}
