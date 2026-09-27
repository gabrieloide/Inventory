import SwiftData
import SwiftUI

struct InventoryDetails: View {
    @Bindable var p: Product
    @State private var initialStock: Int = 0
    @Environment(\.modelContext) var environment

    @State private var initialName: String = ""
    @State private var initialSku: String = ""

    var body: some View {
        List {
            Section(header: Text("Product Information")) {
                HStack {
                    Text("Name")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("Product name", text: $p.name)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("SKU")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .leading)
                    TextField("SKU code", text: $p.sku)
                        .fontWeight(.medium)
                        .textInputAutocapitalization(.characters)
                }
            }

            Section(header: Text("Inventory Stock")) {
                Stepper(value: $p.stock, in: 0...100_000) {
                    HStack {
                        Text("Current stock")
                            .font(.body)
                        Spacer()
                        stockBadge(for: p.stock)
                    }
                }
            }

            Section(header: Text("Stock History")) {
                if p.stockChanges.isEmpty {
                    Text("No stock changes recorded yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(p.stockChanges.sorted(by: { $0.date > $1.date })) { change in
                        HStack(spacing: 12) {
                            Image(systemName: change.delta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(change.delta >= 0 ? Color.green : Color.red)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(change.source)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(change.delta >= 0 ? "+\(change.delta)" : "\(change.delta)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(change.delta >= 0 ? Color.green : Color.red)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(p.name.isEmpty ? "Product Details" : p.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initialStock = p.stock
            initialName = p.name
            initialSku = p.sku
        }
        .onDisappear {
            if p.name.trimmingCharacters(in: .whitespaces).isEmpty {
                p.name = initialName
            }
            if p.sku.trimmingCharacters(in: .whitespaces).isEmpty {
                p.sku = initialSku
            }

            let stockChanged = p.stock != initialStock
            let infoChanged = p.name != initialName || p.sku != initialSku

            if stockChanged || infoChanged {
                if stockChanged {
                    let newStockChange = StockChange(
                        date: Date.now,
                        delta: p.stock - initialStock,
                        source: "Local"
                    )
                    p.stockChanges.append(newStockChange)
                }

                let newPendingOperation = PendingOperation(
                    type: .updateStock,
                    productName: p.name,
                    deltaStock: stockChanged ? p.stock - initialStock : nil,
                    state: .pending,
                    tries: 0,
                    product: p
                )
                environment.insert(newPendingOperation)
                Task { await newPendingOperation.sync() }
            }
        }
    }

    @ViewBuilder
    private func stockBadge(for stock: Int) -> some View {
        let (statusText, color, icon) = stockBadgeDetails(for: stock)
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }

    private func stockBadgeDetails(for stock: Int) -> (String, Color, String) {
        if stock == 0 {
            return ("Out of stock", .red, "xmark.circle.fill")
        } else if stock <= 5 {
            return ("\(stock) left", .orange, "exclamationmark.circle.fill")
        } else {
            return ("\(stock) in stock", .indigo, "checkmark.circle.fill")
        }
    }
}

#Preview {
    let p = Product(name: "iPhone 15", sku: "IPH15", stock: 12)
    InventoryDetails(p: p).modelContainer(
        for: [Product.self, PendingOperation.self], inMemory: true)
}
