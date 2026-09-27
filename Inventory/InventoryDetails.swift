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

            VStack {
                TextField("Product Name", text: $p.name)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                TextField("SKU", text: $p.sku)
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                HStack(spacing: 30) {
                    Button(action: {
                        if p.stock > 0 {
                            p.stock -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                    }.buttonStyle(.plain).foregroundStyle(.blue)

                    VStack {
                        Text(String(p.stock)).font(.system(size: 35)).bold()
                        Text("In stock").font(.caption)
                    }

                    Button(action: { p.stock += 1 }) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                    }.buttonStyle(.plain).foregroundStyle(.blue)

                }.padding(15).frame(maxWidth: .infinity)
            }

            Section(header: Text("History")) {
                ForEach(p.stockChanges.sorted(by: { $0.date > $1.date })) { index in
                    HStack {
                        Image(systemName: "clock").resizable().frame(width: 25, height: 25)

                        VStack(alignment: .leading) {
                            Text(index.date, format: .dateTime.day().month(.abbreviated)).font(
                                .headline)
                            Text(index.source).font(.subheadline)
                        }.padding(.leading, 5.7)
                        Spacer()
                        Text(String(index.delta)).padding(.trailing, 15)
                    }
                    .padding(.vertical, 7)
                }

            }
        }
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
                    type: OperationType.updateStock,
                    productName: p.name,
                    deltaStock: stockChanged ? p.stock - initialStock : nil,
                    state: .pending, tries: 0, product: p
                )
                environment.insert(newPendingOperation)
                Task { await newPendingOperation.sync() }
            }

        }

    }
}
#Preview {
    let p = Product(name: "IPhone", sku: "TLF", stock: 12)
    InventoryDetails(p: p).modelContainer(
        for: [Product.self, PendingOperation.self], inMemory: true)
}
