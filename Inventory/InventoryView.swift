import SwiftUI
import SwiftData

struct InventoryView: View {
    @State private var isPresented: Bool = false
    @State private var searchText: String = ""
    @Query(sort: \Product.name) var products: [Product]
    @Environment(\.modelContext) var environment

    @AppStorage(AppConstants.Storage.offlineMode) var isOfflineMode: Bool = false

    var filteredProducts: [Product] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return products
        }
        return products.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.sku.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isOfflineMode {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Simulated Offline Mode Active")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                }

                Group {
                    if products.isEmpty {
                        ContentUnavailableView(
                            "No Products",
                            systemImage: "shippingbox",
                            description: Text("Tap + to create your first inventory item.")
                        )
                    } else if filteredProducts.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        List {
                            ForEach(filteredProducts) { p in
                                NavigationLink(destination: InventoryDetails(p: p)) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.indigo.opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "shippingbox.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color.indigo)
                                        }

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(p.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Text("SKU: \(p.sku)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        stockBadge(for: p.stock)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .onDelete(perform: deleteProducts)
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search products or SKU")
            .refreshable {
                await SyncEngine.shared.fullSync(context: environment)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isPresented = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Add Product")
                }
            }
        }
        .task {
            await SyncEngine.shared.fullSync(context: environment)
        }
        .sheet(isPresented: $isPresented) {
            InventoryFormView()
        }
    }

    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredProducts[index]
            if let remoteId = item.remoteId {
                let deleteOp = PendingOperation(
                    type: .delete,
                    productName: item.name,
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
            environment.delete(item)
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
    InventoryView()
        .modelContainer(for: [Product.self, PendingOperation.self, StockChange.self], inMemory: true)
}
