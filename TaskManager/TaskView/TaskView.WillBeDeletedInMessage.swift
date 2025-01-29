import SwiftUI

extension TaskView {
    struct WillBeDeletedInMessage: View {
        @State var message: String = ""
        
        let deletedAt: Date
        
        var body: some View {
            Text(self.message)
                .font(.caption)
                .foregroundStyle(.red)
                .onAppear {
                    let formatter = DateComponentsFormatter()
                    
                    formatter.unitsStyle = .abbreviated
                    formatter.allowedUnits = [.day, .hour, .minute]
                    formatter.maximumUnitCount = 1
                    
                    self.message = formatter.string(from: 30.days.ago, to: deletedAt) ?? ""
                }
        }
    }
}
