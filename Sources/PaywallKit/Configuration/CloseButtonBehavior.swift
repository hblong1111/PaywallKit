import Foundation

public enum CloseButtonBehavior: Sendable, Equatable {
    case alwaysVisible
    case hidden
    case visibleAfter(TimeInterval)
}
