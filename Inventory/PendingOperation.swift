import Foundation
import SwiftData

public enum OperationType: String, Codable {
    case make
    case updateStock
    case delete

    public var displayName: String {
        switch self {
        case .make:
            return "Create Product"
        case .updateStock:
            return "Update Stock"
        case .delete:
            return "Delete Product"
        }
    }
}

public enum OperationState: String, Codable {
    case pending
    case inProgress
    case successful
    case failed

    public var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .inProgress:
            return "Syncing"
        case .successful:
            return "Synced"
        case .failed:
            return "Failed"
        }
    }
}

@Model
public class PendingOperation {
    public var type: OperationType
    public var remoteId: Int?
    public var productName: String
    public var product: Product?
    public var deltaStock: Int?
    public var state: OperationState? = OperationState.pending
    public var tries: Int
    public var createdAt: Date? = Date()
    public var errorMessage: String?

    public static let maxRetries = 3

    public init(
        type: OperationType,
        productName: String,
        deltaStock: Int? = nil,
        state: OperationState? = .pending,
        tries: Int = 0,
        product: Product? = nil,
        remoteId: Int? = nil,
        createdAt: Date? = Date(),
        errorMessage: String? = nil
    ) {
        self.type = type
        self.productName = productName
        self.deltaStock = deltaStock
        self.state = state ?? .pending
        self.tries = tries
        self.product = product
        self.remoteId = remoteId
        self.createdAt = createdAt
        self.errorMessage = errorMessage
    }
}
