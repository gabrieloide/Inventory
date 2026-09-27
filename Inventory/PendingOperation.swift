import Foundation
import SwiftData

public enum OperationType: String, Codable {
    case make, updateStock, delete

    var displayName: String {
        switch self {
        case .make:
            return "Make"
        case .updateStock:
            return "Update Stock"
        case .delete:
            return "Delete"
        }
    }
}
public enum OperationState: String, Codable {
    case pending, successful, failed

    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .successful:
            return "Successful"
        case .failed:
            return "Failed"
        }
    }
}
@Model class PendingOperation {
    var type: OperationType
    var remoteId: Int?
    var productName: String
    var product: Product?
    var deltaStock: Int?
    var state: OperationState? = OperationState.pending
    var tries: Int
    static let maxRetries = 3
    

    init(
        type: OperationType, productName: String, deltaStock: Int? = nil, state: OperationState? = .pending, tries: Int,
        product: Product?, remoteId: Int? = nil
    ) {
        self.type = type
        self.productName = productName
        self.product = product
        self.deltaStock = deltaStock
        self.state = state ?? .pending
        self.tries = tries
        self.remoteId = remoteId
    }

    func upsert() async throws {
        guard let product else {
            state = .successful
            return
        }

        let dto = ProductDTO(
            productId: product.remoteId ?? 0, name: product.name, sku: product.sku,
            stock: product.stock)

        if product.remoteId != nil {
            let updated = try await ProductAPI.updateProduct(dto)
            product.remoteId = updated.productId
        } else {
            let created = try await ProductAPI.createProduct(dto)
            product.remoteId = created.productId
        }
        state = .successful
    }

    func sync(force: Bool = false) async {
        if tries >= PendingOperation.maxRetries && !force {
            return
        }

        if UserDefaults.standard.bool(forKey: AppConstants.Storage.offlineMode) {
            return
        }
        do {
            switch self.type {
            case .make, .updateStock:
                try await upsert()

            case  .delete:
                guard let id: Int = self.remoteId else {
                    state = .successful
                    return
                }
                try await ProductAPI.deleteProduct(productId: id)
                state = .successful
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.Storage.lastSync)
        } catch {
            print("Error syncing pending operation: \(error)")
            state = .failed
            tries += 1
        }
    }
}
