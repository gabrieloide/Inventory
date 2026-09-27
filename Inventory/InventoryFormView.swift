import SwiftUI
import SwiftData

struct InventoryFormView: View {
    
    @State var name: String = ""
    @State var sku: String = ""
    @State var stock: Int = 0
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var environment
    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && 
        !sku.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    func saveData(){

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedSku = sku.trimmingCharacters(in: .whitespaces)

        let product = Product(name: trimmedName, sku: trimmedSku, stock: stock)
        let pendingOperation = PendingOperation(type: OperationType.make, productName: product.name,deltaStock: nil, state: .pending, tries: 0, product: product)
        
        environment.insert(pendingOperation)
        environment.insert(product)

        Task{ await pendingOperation.sync() }

        dismiss()
    }
    
    var body: some View {
        
        NavigationStack{
            Form{
                Section{
                
                    TextField(
                        "Type product name",
                        text: $name
                    )
                    TextField(
                        "SKU",
                        text: $sku
                    )
                }
                Section{
                    HStack(spacing: 30){
                        
                        Button(action: {
                            if(stock > 0){
                                stock -= 1
                            }
                        }) {
                            
                            Image(systemName: "minus.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }.buttonStyle(.plain).foregroundStyle(.blue)
                        
                        VStack{
                            Text(String(stock)).font(.system(size:35)).bold()
                            Text("In stock").font(.caption)
                        }
                        
                        Button(action: {stock += 1 }) {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }.buttonStyle(.plain).foregroundStyle(.blue)
                        
                    }.padding(15).frame(maxWidth: .infinity)
                }
            }
            .toolbar{
                ToolbarItem(placement: .topBarLeading){
                    Button(action:{dismiss()}){
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .topBarTrailing){
                    Button(action: {saveData()} ){
                        Text("Save")
                        
                    }
                    .disabled(!isFormValid)
                }
                
            }
            
        }
        
    }

}

#Preview {
    InventoryFormView()
}
