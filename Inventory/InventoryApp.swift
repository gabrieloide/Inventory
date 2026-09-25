import SwiftUI
import SwiftData

@main
struct InventoryApp: App {
    var body: some Scene {
        WindowGroup {
            InventoryTabView().modelContainer(for: [Product.self, PendingOperation.self])
                
        }
    }
}
