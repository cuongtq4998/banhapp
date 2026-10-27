import SwiftUI

enum Motion {
    static let short: TimeInterval = 0.15
    static let medium: TimeInterval = 0.25
    static let long: TimeInterval = 0.4
    static let standardSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)
    /// How long a `Toast` stays (design system, Toast component).
    static let toastDuration: Duration = .seconds(4)
    /// Scale of a pressed bar action.
    static let pressedScale: CGFloat = 0.97
    static let disabledOpacity: Double = 0.5
}
