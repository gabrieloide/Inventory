import Foundation
import SwiftData

@Model
public class Product {
    public var name: String
    public var sku: String
    public var stock: Int
    public var remoteId: Int?

    @Relationship(deleteRule: .cascade)
    public var stockChanges: [StockChange] = []

    @Relationship(deleteRule: .cascade, inverse: \PendingOperation.product)
    public var pendingOperations: [PendingOperation] = []

    public init(name: String, sku: String, stock: Int, remoteId: Int? = nil) {
        self.name = name
        self.sku = sku
        self.stock = stock
        self.remoteId = remoteId
    }
}

@Model
public class StockChange {
    public var date: Date
    public var delta: Int
    public var source: String

    public init(date: Date, delta: Int, source: String) {
        self.date = date
        self.delta = delta
        self.source = source
    }
}
