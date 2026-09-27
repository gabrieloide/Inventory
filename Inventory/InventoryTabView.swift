import SwiftData
import SwiftUI

struct InventoryTabView: View {
    @State private var monitor = NetworkMonitor()
    @Environment(\.modelContext) var environment
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
                .tag(0)

            PendingView()
                .tabItem {
                    Label("Queue", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(1)

            DiagnosticView()
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
                .tag(2)
        }
        .tint(.indigo)
        .onChange(of: monitor.isConnected) { _, isConnected in
            if isConnected {
                Task {
                    await SyncEngine.shared.fullSync(context: environment)
                }
            }
        }
        .onAppear {
            Task {
                await SyncEngine.shared.fullSync(context: environment)
            }
        }
    }
}

#Preview {
    InventoryTabView()
        .modelContainer(for: [Product.self, PendingOperation.self, StockChange.self], inMemory: true)
}
