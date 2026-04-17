import SwiftUI
import PaywallKit

struct PopupContainer<Content: View>: View {
    let backdrop: BackdropStyle
    @ViewBuilder let content: () -> Content

    @Environment(PaywallManager.self) private var manager

    var body: some View {
        ZStack {
            backdropView
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { await manager.dismiss(reason: .user) }
                }

            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(surfaceColor)
                )
                .shadow(radius: 20)
                .padding(24)
        }
        .ignoresSafeArea()
    }

    private var surfaceColor: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    @ViewBuilder
    private var backdropView: some View {
        switch backdrop {
        case .dim(let opacity):
            Color.black.opacity(opacity)
        case .blur:
            Rectangle().fill(.ultraThinMaterial)
        case .clear:
            Color.clear
        }
    }
}
