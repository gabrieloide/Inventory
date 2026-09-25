import SwiftUI
import SwiftData

struct InventoryDetails: View {
    var p: Product
    @State private var initialStock: Int = 0
    @Environment(\.modelContext) var environment
    
    var body: some View {
        
        List {
            
            VStack{
                Text(p.name).font(.system(size: 25))
                Text(p.sku).font(.system(size: 17))
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            
            Section{
                HStack(spacing: 30){
                    Button(action: {
                        if(p.stock > 0)
                        {
                            p.stock -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                    }.buttonStyle(.plain).foregroundStyle(.blue)
                    
                    VStack{
                        Text(String(p.stock)).font(.system(size:35)).bold()
                        Text("In stock").font(.caption)
                    }
                    
                    Button(action: {p.stock += 1}) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                    }.buttonStyle(.plain).foregroundStyle(.blue)
                    
                }.padding(15).frame(maxWidth: .infinity)
            }
            
            Section(header: Text("History")){
                ForEach(p.stockChanges.sorted(by: {$0.date > $1.date})) { index in
                    HStack{
                        Image(systemName: "clock").resizable().frame(width: 25, height: 25)
                        
                        VStack(alignment: .leading){
                            Text(index.date, format: .dateTime.day().month(.abbreviated)).font(.headline)
                            Text(index.source).font(.subheadline)
                        }.padding(.leading, 5.7)
                        Spacer()
                        Text(String(index.delta)).padding(.trailing, 15)
                    }
                    .padding(.vertical, 7)
                }
                
            }
        }
        .onAppear{
            initialStock = p.stock
        }
        .onDisappear{
            if(p.stock - initialStock != 0)
            {
                let newStockChange = StockChange(
                    date: Date.now, delta: p.stock - initialStock,source: "Local")
                
                let newPendingOperation = PendingOperation(type: OperationType.updateStock, productName: p.name, deltaStock: p.stock - initialStock, state: "pending", tries: 0, product: p)
                p.stockChanges.append(newStockChange)
                environment.insert(newPendingOperation)

                Task { await newPendingOperation.sync() }
            }
        }
        
    }
}
#Preview{
    let p = Product(name: "IPhone", sku: "TLF", stock: 12)
    InventoryDetails(p: p).modelContainer(for:[Product.self, PendingOperation.self], inMemory: true)
}
