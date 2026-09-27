import SwiftData
import SwiftUI

struct InventoryTabView: View {

    @State private var monitor = NetworkMonitor()
    @Query(filter: #Predicate<PendingOperation> { $0.state.rawValue != "successful" })
    var openOperations: [PendingOperation]

    func syncPendingOperations() async {
        for operation in openOperations { await operation.sync() }
    }
    var body: some View {
        TabView {
            InventoryView().tabItem {
                Image(systemName: "shippingbox")
                Text("Inventory")
            }
            PendingView().tabItem {
                Image(systemName: "list.clipboard")
                Text("Pending")
            }
            DiagnosticView().tabItem {
                Image(systemName: "stethoscope")
                Text("Diagnostic")
            }
        }
        .onChange(of: monitor.isConnected) { _, isConnected in
            if isConnected {
                Task {
                    await syncPendingOperations()
                }
            }
        }
        .onAppear {
            Task {
                await syncPendingOperations()
            }
        }
    }
}

#Preview {
    InventoryTabView().modelContainer(for: Product.self, inMemory: true)
}
