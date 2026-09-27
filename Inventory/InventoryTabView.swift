import SwiftData
import SwiftUI

struct InventoryTabView: View {
    @State private var monitor = NetworkMonitor()
    @Query(filter: #Predicate<PendingOperation> { $0.state.rawValue != "successful" })
    var openOperations: [PendingOperation]

    func syncPendingOperations() async {
        for operation in openOperations {
            await operation.sync()
        }
    }

    var body: some View {
        TabView {
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
            
            PendingView()
                .tabItem {
                    Label("Queue", systemImage: "arrow.triangle.2.circlepath")
                }
            
            DiagnosticView()
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
        }
        .tint(.indigo)
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
    InventoryTabView().modelContainer(
        for: [Product.self, PendingOperation.self], inMemory: true)
}
