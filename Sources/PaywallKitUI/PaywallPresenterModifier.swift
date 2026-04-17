import SwiftUI
import PaywallKit

public extension View {
    /// Gắn ở root view. Tự động show/dismiss paywall theo `PaywallManager.presentedType`,
    /// resolve presentation style từ `PaywallConfiguration` của mỗi paywall type.
    func paywallPresenter(registry: PaywallRegistry) -> some View {
        modifier(PaywallPresenterModifier(registry: registry))
    }
}

struct PaywallPresenterModifier: ViewModifier {
    let registry: PaywallRegistry
    @Environment(PaywallManager.self) private var manager

    func body(content: Content) -> some View {
        content
            .sheet(item: sheetItem) { ctx in
                paywallContent(for: ctx.type)
                    .environment(manager)
                    .presentationDetents(mapDetents(ctx.detents))
            }
            .modifier(FullScreenCoverFallback(item: fullScreenItem) { type in
                paywallContent(for: type)
                    .environment(manager)
            })
            .overlay {
                if let popup = popupContext {
                    PopupContainer(backdrop: popup.backdrop) {
                        paywallContent(for: popup.type)
                    }
                    .environment(manager)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: popup.id)
                }
            }
    }

    @ViewBuilder
    private func paywallContent(for type: PaywallType) -> some View {
        if let view = registry.makeView(for: type) {
            view
        } else {
            Text("No view registered for \(type.rawValue)")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Presentation bindings

    private var sheetItem: Binding<SheetContext?> {
        Binding {
            guard let type = manager.presentedType,
                  let config = manager.currentConfiguration,
                  case .sheet(let detents) = config.presentation
            else { return nil }
            return SheetContext(id: type.rawValue, type: type, detents: detents)
        } set: { newValue in
            if newValue == nil { Task { await manager.dismiss(reason: .user) } }
        }
    }

    private var fullScreenItem: Binding<FullScreenContext?> {
        Binding {
            guard let type = manager.presentedType,
                  let config = manager.currentConfiguration,
                  case .fullScreenCover = config.presentation
            else { return nil }
            return FullScreenContext(id: type.rawValue, type: type)
        } set: { newValue in
            if newValue == nil { Task { await manager.dismiss(reason: .user) } }
        }
    }

    private var popupContext: PopupContext? {
        guard let type = manager.presentedType,
              let config = manager.currentConfiguration,
              case .popup(let backdrop) = config.presentation
        else { return nil }
        return PopupContext(id: type.rawValue, type: type, backdrop: backdrop)
    }

    private func mapDetents(_ detents: Set<SheetDetent>) -> Set<PresentationDetent> {
        Set(detents.map { detent -> PresentationDetent in
            switch detent {
            case .medium: .medium
            case .large: .large
            case .fraction(let f): .fraction(f)
            case .height(let h): .height(h)
            }
        })
    }
}

private struct SheetContext: Identifiable, Equatable {
    let id: String
    let type: PaywallType
    let detents: Set<SheetDetent>
}

/// iOS có `fullScreenCover`; macOS fallback về `sheet` để target UI vẫn build được cross-platform.
private struct FullScreenCoverFallback<InnerContent: View>: ViewModifier {
    let item: Binding<FullScreenContext?>
    let content: (PaywallType) -> InnerContent

    func body(content base: Content) -> some View {
        #if os(iOS)
        base.fullScreenCover(item: item) { ctx in
            self.content(ctx.type)
        }
        #else
        base.sheet(item: item) { ctx in
            self.content(ctx.type)
        }
        #endif
    }
}

private struct FullScreenContext: Identifiable, Equatable {
    let id: String
    let type: PaywallType
}

private struct PopupContext: Identifiable, Equatable {
    let id: String
    let type: PaywallType
    let backdrop: BackdropStyle
}
