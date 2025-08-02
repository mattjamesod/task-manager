import SwiftUI
import KillerStyle

extension KillerNavigation {
    struct StackHeader<Selection: Hashable & ProvidesNavigationHeader>: View {
        @Binding var selection: Selection?
        
       var body: some View {
           VStack(spacing: 0) {
               HStack {
                   self.backButton
                       .buttonStyle(KillerInlineButtonStyle())
                   
                   selection?.headerContent
               }
               .padding(.horizontal, 12)
               .padding(.vertical, 12)
               .frame(maxWidth: .infinity, alignment: .leading)
               
               Divider()
           }
           .background {
               Rectangle()
                   .foregroundStyle(.ultraThinMaterial)
                   .ignoresSafeArea()
           }
       }
        
        private var backButton: some View {
            Button {
                selection = nil
            } label: {
                Label("Back", systemImage: "chevron.backward")
                    .containerPadding(axis: .horizontal)
                    .labelStyle(.iconOnly)
                    .fontWeight(.semibold)
            }
        }
    }
}

// liquid glass?
//var body: some View {
//    HStack {
//        self.backButton
//            .buttonStyle(KillerFloatingButtonStyle())
//    
//        selection?.headerContent
//    }
//    .padding(.horizontal, 12)
////            .padding(.vertical, 12)
//    .frame(maxWidth: .infinity, alignment: .leading)
//}

public protocol ProvidesNavigationHeader {
    associatedtype HeaderViewContent: View
    var headerContent: HeaderViewContent { get }
}

public enum KillerSystemDesign: Sendable {
    case flat
    case liquid
}

struct KillerSystemDesignKey: PreferenceKey {
    static let defaultValue: KillerSystemDesign = .flat

    static func reduce(value: inout KillerSystemDesign, nextValue: () -> KillerSystemDesign) {
        value = nextValue()
    }
}

public extension View {
    func killerSystemDesign(_ design: KillerSystemDesign) -> some View {
        self.preference(key: KillerSystemDesignKey.self, value: design)
    }
}
