import SwiftUI
import SwiftData

struct InventoryFormView: View {
    @State private var name: String = ""
    @State private var sku: String = ""
    @State private var stock: Int = 0
    @State private var validationError: String? = nil

    @Query var existingProducts: [Product]
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var environment

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty &&
        stock >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Product Details")) {
                    TextField("Product name", text: $name)

                    TextField("SKU code", text: $sku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if let validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(header: Text("Initial Stock")) {
                    Stepper("Quantity: \(stock)", value: $stock, in: 0...100_000)
                }
            }
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveData()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveData() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSku = sku.trimmingCharacters(in: .whitespaces).uppercased()

        // Local duplicate SKU check
        if existingProducts.contains(where: { $0.sku.uppercased() == trimmedSku }) {
            validationError = "A product with SKU '\(trimmedSku)' already exists."
            return
        }

        let product = Product(name: trimmedName, sku: trimmedSku, stock: stock)
        if stock > 0 {
            product.stockChanges.append(
                StockChange(date: Date(), delta: stock, source: "Initial Stock")
            )
        }

        let pendingOperation = PendingOperation(
            type: .make,
            productName: product.name,
            deltaStock: nil,
            state: .pending,
            tries: 0,
            product: product
        )

        environment.insert(product)
        environment.insert(pendingOperation)

        Task {
            await SyncEngine.shared.processQueue(context: environment)
        }

        dismiss()
    }
}

#Preview {
    InventoryFormView()
        .modelContainer(for: [Product.self, PendingOperation.self, StockChange.self], inMemory: true)
}
