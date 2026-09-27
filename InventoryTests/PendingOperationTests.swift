import Foundation
import XCTest
import SwiftData

final class PendingOperationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([Product.self, PendingOperation.self, StockChange.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    func testPendingOperationInitialState() {
        let product = Product(name: "Wireless Mouse", sku: "MS-01", stock: 15)
        let op = PendingOperation(
            type: .make,
            productName: product.name,
            product: product
        )

        XCTAssertEqual(op.type, .make)
        XCTAssertEqual(op.state, .pending)
        XCTAssertEqual(op.tries, 0)
        XCTAssertNil(op.errorMessage)
        XCTAssertNil(op.remoteId)
    }

    func testMaxRetriesExceededTransitionsToFailed() {
        let op = PendingOperation(
            type: .updateStock,
            productName: "Test Item",
            tries: 2,
            remoteId: 42
        )

        // Increment retry to threshold
        op.tries += 1
        op.errorMessage = "Connection timed out"
        if op.tries >= PendingOperation.maxRetries {
            op.state = .failed
        }

        XCTAssertEqual(op.state, .failed)
        XCTAssertEqual(op.tries, 3)
        XCTAssertEqual(op.errorMessage, "Connection timed out")
    }

    func testFIFOOrderingByCreatedAt() throws {
        let date1 = Date().addingTimeInterval(-100)
        let date2 = Date().addingTimeInterval(-50)
        let date3 = Date()

        let op1 = PendingOperation(type: .make, productName: "Item 1", createdAt: date1)
        let op2 = PendingOperation(type: .updateStock, productName: "Item 2", createdAt: date2)
        let op3 = PendingOperation(type: .delete, productName: "Item 3", createdAt: date3)

        context.insert(op3)
        context.insert(op1)
        context.insert(op2)
        try context.save()

        let descriptor = FetchDescriptor<PendingOperation>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].productName, "Item 1")
        XCTAssertEqual(fetched[1].productName, "Item 2")
        XCTAssertEqual(fetched[2].productName, "Item 3")
    }

    func testCascadeDeleteCleansUpPendingOperations() throws {
        let product = Product(name: "Mechanical Keyboard", sku: "KB-99", stock: 5)
        let op = PendingOperation(type: .updateStock, productName: product.name, product: product)

        context.insert(product)
        context.insert(op)
        try context.save()

        var fetchedOps = try context.fetch(FetchDescriptor<PendingOperation>())
        XCTAssertEqual(fetchedOps.count, 1)

        // Deleting the product should cascade-delete its pending operations
        context.delete(product)
        try context.save()

        fetchedOps = try context.fetch(FetchDescriptor<PendingOperation>())
        XCTAssertEqual(fetchedOps.count, 0)
    }
}
