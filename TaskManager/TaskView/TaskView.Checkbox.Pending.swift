import SwiftUI

extension TaskView.Checkbox {
    struct Pending: View {
        @ScaledMetric private var checkboxWidth: Double = TaskView.Checkbox.WIDTH
        @ScaledMetric private var checkboxBorderWidth: Double = TaskView.Checkbox.BORDER_WIDTH
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                    .strokeBorder(style: .init(
                        lineWidth: self.checkboxBorderWidth, dash: [2]
                    ))
                    .foregroundStyle(.gray)
                
                RoundedRectangle(cornerRadius: self.checkboxWidth / 3)
                    .foregroundStyle(.clear)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(width: self.checkboxWidth)
            .contentShape(Rectangle())
        }
    }
}
