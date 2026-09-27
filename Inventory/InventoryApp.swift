import SwiftUI
import SwiftData

@main
struct InventoryApp: App {
    let container: ModelContainer
    @AppStorage("screenshotView") var screenshotView: String = ""

    init() {
        do {
            let schema = Schema([Product.self, PendingOperation.self, StockChange.self])
            let config = ModelConfiguration(schema: schema)
            let modelContainer = try ModelContainer(for: schema, configurations: [config])
            self.container = modelContainer

            let context = modelContainer.mainContext
            let descriptor = FetchDescriptor<Product>()
            let existingCount = (try? context.fetchCount(descriptor)) ?? 0
            if existingCount == 0 {
                Self.seedInitialData(context: context)
            }
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if screenshotView == "form" {
                    InventoryFormView()
                } else if screenshotView == "details" {
                    DetailsContainerView()
                } else {
                    InventoryTabView()
                }
            }
        }
        .modelContainer(container)
    }

    private static func seedInitialData(context: ModelContext) {
        let macbook = Product(name: "MacBook Pro 16\"", sku: "MBP-16-M3", stock: 12, remoteId: 1)
        macbook.stockChanges.append(StockChange(date: Date().addingTimeInterval(-86400 * 2), delta: 12, source: "Initial Intake"))

        let monitor = Product(name: "Studio Display 27\"", sku: "DISP-27-5K", stock: 4, remoteId: 2)
        monitor.stockChanges.append(StockChange(date: Date().addingTimeInterval(-86400 * 3), delta: 5, source: "Initial Intake"))
        monitor.stockChanges.append(StockChange(date: Date().addingTimeInterval(-86400), delta: -1, source: "Order #8921"))

        let keyboard = Product(name: "Mechanical Keyboard Pro", sku: "KB-MECH-RGB", stock: 0, remoteId: 3)
        keyboard.stockChanges.append(StockChange(date: Date().addingTimeInterval(-86400 * 5), delta: 10, source: "Intake"))
        keyboard.stockChanges.append(StockChange(date: Date().addingTimeInterval(-3600 * 4), delta: -10, source: "Fulfillment"))

        let mouse = Product(name: "Wireless Precision Mouse", sku: "MSE-PREC-01", stock: 28, remoteId: 4)
        mouse.stockChanges.append(StockChange(date: Date().addingTimeInterval(-86400), delta: 28, source: "Shipment #334"))

        let syncedOp = PendingOperation(
            type: .make,
            productName: "MacBook Pro 16\"",
            state: .successful,
            tries: 0,
            product: macbook,
            remoteId: 1,
            createdAt: Date().addingTimeInterval(-3600)
        )

        let pendingOp = PendingOperation(
            type: .updateStock,
            productName: "Studio Display 27\"",
            deltaStock: -1,
            state: .pending,
            tries: 0,
            product: monitor,
            remoteId: 2,
            createdAt: Date().addingTimeInterval(-600)
        )

        context.insert(macbook)
        context.insert(monitor)
        context.insert(keyboard)
        context.insert(mouse)
        context.insert(syncedOp)
        context.insert(pendingOp)
        try? context.save()
    }
}

struct DetailsContainerView: View {
    @Query(sort: \Product.name) var products: [Product]

    var body: some View {
        NavigationStack {
            if let p = products.first(where: { $0.sku == "DISP-27-5K" }) ?? products.first {
                InventoryDetails(p: p)
            } else {
                Text("No Product Found")
            }
        }
    }
}
