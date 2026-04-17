import Foundation

public enum PresentationStyle: Sendable {
    case sheet(detents: Set<SheetDetent> = [.large])
    case fullScreenCover
    case popup(backdrop: BackdropStyle = .dim(opacity: 0.5))
}

public enum SheetDetent: Hashable, Sendable {
    case medium
    case large
    case fraction(Double)
    case height(CGFloat)
}

public enum BackdropStyle: Sendable, Equatable {
    case dim(opacity: Double)
    case blur
    case clear
}
