import SwiftUI
import SwiftData

struct InventoryTabView: View {
    var body: some View {
        TabView{
            InventoryView().tabItem{
                Image(systemName:"shippingbox")
                Text("Inventory")
            }
            PendingView().tabItem{
                Image(systemName:"list.clipboard")
                Text("Pending")
            }
            DiagnosticView().tabItem{
                Image(systemName:"stethoscope")
                Text("Diagnostic")
            }
        }
    }
}

#Preview {
    InventoryTabView().modelContainer(for:Product.self, inMemory: true)
}
