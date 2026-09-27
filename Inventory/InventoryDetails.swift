import SwiftData
import SwiftUI

struct InventoryDetails: View {
    @Bindable var p: Product
    @State private var initialStock: Int = 0
    @State private var initialName: String = ""
    @State private var initialSku: String = ""

    @Environment(\.modelContext) var environment
    @Environment(\.dismiss) var dismiss

    @State private var showingDeleteConfirmation: Bool = false
    @State private var isDeleted: Bool = false

    var hasChanges: Bool {
        p.stock != initialStock ||
        p.name.trimmingCharacters(in: .whitespaces) != initialName ||
        p.sku.trimmingCharacters(in: .whitespaces) != initialSku
    }

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
                        .autocorrectionDisabled()
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

            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Delete Product", systemImage: "trash")
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(p.name.isEmpty ? "Product Details" : p.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete Product", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteCurrentProduct()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this product? This action cannot be undone.")
        }
        .onAppear {
            initialStock = p.stock
            initialName = p.name
            initialSku = p.sku
        }
        .onDisappear {
            saveChangesIfAny()
        }
    }

    private func saveChangesIfAny() {
        if isDeleted { return }

        let trimmedName = p.name.trimmingCharacters(in: .whitespaces)
        let trimmedSku = p.sku.trimmingCharacters(in: .whitespaces).uppercased()

        if trimmedName.isEmpty {
            p.name = initialName
        }
        if trimmedSku.isEmpty {
            p.sku = initialSku
        }

        let stockChanged = p.stock != initialStock
        let infoChanged = p.name != initialName || p.sku != initialSku

        guard stockChanged || infoChanged else { return }

        if stockChanged {
            let delta = p.stock - initialStock
            let newStockChange = StockChange(
                date: Date.now,
                delta: delta,
                source: "Manual Edit"
            )
            p.stockChanges.append(newStockChange)
        }

        let newPendingOperation = PendingOperation(
            type: .updateStock,
            productName: p.name,
            deltaStock: stockChanged ? p.stock - initialStock : nil,
            state: .pending,
            tries: 0,
            product: p,
            remoteId: p.remoteId
        )

        environment.insert(newPendingOperation)
        Task {
            await SyncEngine.shared.processQueue(context: environment)
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

    private func deleteCurrentProduct() {
        isDeleted = true
        if let remoteId = p.remoteId {
            let deleteOp = PendingOperation(
                type: .delete,
                productName: p.name,
                state: .pending,
                tries: 0,
                product: nil,
                remoteId: remoteId
            )
            environment.insert(deleteOp)
            Task {
                await SyncEngine.shared.processQueue(context: environment)
            }
        }
        environment.delete(p)
        dismiss()
    }
}

#Preview {
    let p = Product(name: "iPhone 15", sku: "IPH15", stock: 12)
    InventoryDetails(p: p)
        .modelContainer(for: [Product.self, PendingOperation.self, StockChange.self], inMemory: true)
}
