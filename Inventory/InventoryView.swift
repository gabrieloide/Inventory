import SwiftUI
import SwiftData

struct InventoryView: View {
    @State private var isPresented: Bool = false
    @State private var searchText: String = ""
    @Query var product: [Product]
    @Query(filter: #Predicate<PendingOperation> { $0.state.rawValue != "successful" }) var pendingOperations: [PendingOperation]
    @Environment(\.modelContext) var environment
    
    var filteredProducts: [Product] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return product
        }
        return product.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.sku.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func refreshRemoteProducts() async {
        do {
            let remoteProducts = try await ProductAPI.getProducts()
            
            for dto in remoteProducts {
                let pendingDelete = pendingOperations.contains(where: { $0.remoteId == dto.productId && $0.type == .delete })
                if pendingDelete { continue }

                if let existing = product.first(where: { $0.remoteId == dto.productId }) {
                    existing.stock = dto.stock
                    existing.name = dto.name
                    existing.sku = dto.sku
                } else {
                    let newProduct = Product(name: dto.name, sku: dto.sku, stock: dto.stock, remoteId: dto.productId)
                    environment.insert(newProduct)
                }
            }
        } catch {
            print("Error refreshing remote products: \(error)")
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if product.isEmpty {
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
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search products or SKU")
            .refreshable {
                await refreshRemoteProducts()
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
            await refreshRemoteProducts()
        }
        .sheet(isPresented: $isPresented) {
            InventoryFormView()
        }
    }

    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredProducts[index]
            if let remoteId = item.remoteId {
                let operation = PendingOperation(
                    type: .delete,
                    productName: item.name,
                    state: .pending,
                    tries: 0,
                    product: nil,
                    remoteId: remoteId
                )
                environment.insert(operation)
                Task {
                    await operation.sync()
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
    InventoryView().modelContainer(for: [Product.self, PendingOperation.self], inMemory: true)
}
