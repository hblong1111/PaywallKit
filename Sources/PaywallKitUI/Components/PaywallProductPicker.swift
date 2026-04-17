import SwiftUI
import PaywallKit
import StoreKit

public struct PaywallProductPicker<Row: View>: View {
    @Environment(PaywallManager.self) private var manager
    private let row: (Product, Bool) -> Row

    public init(@ViewBuilder row: @escaping (_ product: Product, _ isSelected: Bool) -> Row) {
        self.row = row
    }

    public var body: some View {
        if !manager.selection.isSingleProduct {
            VStack(spacing: 8) {
                ForEach(manager.selection.available) { product in
                    let isSelected = manager.selection.selected?.id == product.id
                    Button {
                        manager.selection.selectByID(product.id)
                    } label: {
                        row(product, isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
