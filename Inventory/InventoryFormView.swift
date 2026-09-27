import SwiftUI
import SwiftData

struct InventoryFormView: View {
    @State private var name: String = ""
    @State private var sku: String = ""
    @State private var stock: Int = 0
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var environment
    
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sku.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func saveData() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSku = sku.trimmingCharacters(in: .whitespaces)

        let product = Product(name: trimmedName, sku: trimmedSku, stock: stock)
        let pendingOperation = PendingOperation(
            type: .make,
            productName: product.name,
            deltaStock: nil,
            state: .pending,
            tries: 0,
            product: product
        )
        
        environment.insert(pendingOperation)
        environment.insert(product)

        Task { await pendingOperation.sync() }
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Product Details")) {
                    TextField("Product name", text: $name)
                    TextField("SKU code", text: $sku)
                        .textInputAutocapitalization(.characters)
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
}

#Preview {
    InventoryFormView()
}
