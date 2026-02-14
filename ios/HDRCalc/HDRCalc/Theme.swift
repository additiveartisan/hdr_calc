import SwiftUI

enum Theme {
    static let pagePadding: CGFloat = 24
    static let pagePaddingIPad: CGFloat = 48
    static let cardPadding: CGFloat = 16
    static let cardGap: CGFloat = 12
    static let sectionGap: CGFloat = 24
    static let cardRadius: CGFloat = 12

    static func setColor(_ index: Int) -> Color {
        index % 2 == 0 ? Color.accentColor : .bracket2
    }
}
