import SwiftUI
import SwiftData

struct InventoryView: View {
    @State var isPresented: Bool = false
    @Query var product: [Product]
    @Query(filter: #Predicate <PendingOperation> {$0.state != "successful"}) var pendingOperations: [PendingOperation]
    @Environment(\.modelContext) var environment
    
    var body: some View {
        NavigationStack{
            List {
                ForEach(product) { p in
                    NavigationLink(destination: InventoryDetails(p: p)) {
                        VStack(alignment: .leading){
                            Text(p.name).bold()
                            Text("SKU: \(p.sku) • Stock: \(p.stock)").font(.caption)
                        }
                        
                    }
                    .padding(.vertical, 7)
                }.onDelete(perform: { indexSet in
                for index in indexSet {

                    let item = product[index]

                    if item.remoteId != nil {

                        let operation = PendingOperation(type: .delete, productName: item.name, state: "pending", tries: 0, product: nil, remoteId: item.remoteId)
                        environment.insert(operation)
                        Task{
                            await operation.sync()
                        }
                    }
                    environment.delete(item)
                }
                })

            }.listStyle(.insetGrouped)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement: .principal)
                    {
                        Text("Inventory").font(.system(size: 20)).bold()
                    }
                    ToolbarItem(placement: .topBarTrailing){
                        Button(action:{ isPresented = true})
                        {	
                            Image(systemName: "plus.circle.fill")
                            
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }
        }.task {
            do{
                let remoteProducts = try await ProductAPI.getProducts()
                
                for dto in remoteProducts {
                    
                    let pendingDelete = pendingOperations.contains(where: { $0.remoteId == dto.productId && $0.type == .delete })

                    if pendingDelete { continue }

                    if let existing = product.first(where: {$0.remoteId == dto.productId}){
                        existing.stock = dto.stock
                        existing.name = dto.name
                        existing.sku = dto.sku
                    }else{
                        let existing = Product(name: dto.name, sku: dto.sku, stock: dto.stock, remoteId: dto.productId)
                        environment.insert(existing)
                    }
                }

                
            }
            catch {
                print(error)
            }
        }
        .sheet(isPresented: $isPresented){
            InventoryFormView()
        }
    }
}

#Preview {
    InventoryView().modelContainer(for:[Product.self, PendingOperation.self])
}
