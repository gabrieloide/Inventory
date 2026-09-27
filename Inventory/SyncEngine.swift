import Foundation
import SwiftData
import Observation

@MainActor
@Observable
public final class SyncEngine {
    public static let shared = SyncEngine()

    public var isSyncing: Bool = false
    public var lastSyncError: String? = nil

    private init() {}

    /// Performs full bidirectional synchronization:
    /// 1. Flushes local pending operations queue in FIFO order to the server.
    /// 2. Pulls and reconciles remote server changes without overwriting local uncommitted edits.
    public func fullSync(context: ModelContext, force: Bool = false) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        if isOfflineModeActive() {
            return
        }

        await processQueue(context: context, force: force)
        await reconcileRemote(context: context)
    }

    /// Processes all pending operations in FIFO order
    public func processQueue(context: ModelContext, force: Bool = false) async {
        if isOfflineModeActive() {
            return
        }

        let descriptor = FetchDescriptor<PendingOperation>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let operations = try? context.fetch(descriptor) else { return }

        let openOperations = operations.filter { op in
            let state = op.state ?? .pending
            if state == .successful { return false }
            if !force && op.tries >= PendingOperation.maxRetries && state == .failed {
                return false
            }
            return true
        }

        for operation in openOperations {
            await executeOperation(operation, context: context)
        }

        try? context.save()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.Storage.lastSync)
    }

    private func executeOperation(_ op: PendingOperation, context: ModelContext) async {
        op.state = .inProgress
        do {
            switch op.type {
            case .make:
                guard let product = op.product else {
                    op.state = .successful
                    return
                }

                if let existingRemoteId = product.remoteId, existingRemoteId > 0 {
                    op.remoteId = existingRemoteId
                    op.state = .successful
                    op.errorMessage = nil
                    return
                }

                let req = CreateProductRequest(name: product.name, sku: product.sku, stock: product.stock)
                let created = try await ProductAPI.createProduct(req)

                product.remoteId = created.productId
                op.remoteId = created.productId
                op.state = .successful
                op.errorMessage = nil

                // Propagate the newly acquired remoteId to any subsequent pending operations for this product
                if let pendingOps = product.pendingOperations as [PendingOperation]? {
                    for subsequent in pendingOps where subsequent.remoteId == nil {
                        subsequent.remoteId = created.productId
                    }
                }

            case .updateStock:
                guard let product = op.product else {
                    op.state = .successful
                    return
                }

                guard let remoteId = product.remoteId ?? op.remoteId else {
                    // Cannot update stock if the product has not been created on the server yet.
                    // Keep in pending state so it runs after make completes.
                    op.state = .pending
                    return
                }

                let req = UpdateProductRequest(name: product.name, sku: product.sku, stock: product.stock)
                _ = try await ProductAPI.updateProduct(id: remoteId, req)

                op.state = .successful
                op.errorMessage = nil

            case .delete:
                guard let remoteId = op.remoteId else {
                    // Item was created offline and deleted offline; nothing to delete remotely
                    op.state = .successful
                    op.errorMessage = nil
                    return
                }

                try await ProductAPI.deleteProduct(productId: remoteId)
                op.state = .successful
                op.errorMessage = nil
            }
        } catch {
            op.tries += 1
            op.errorMessage = error.localizedDescription
            if op.tries >= PendingOperation.maxRetries {
                op.state = .failed
            } else {
                op.state = .pending
            }
            lastSyncError = error.localizedDescription
        }
    }

    /// Pulls remote catalog and reconciles with local SwiftData storage
    public func reconcileRemote(context: ModelContext) async {
        if isOfflineModeActive() {
            return
        }

        do {
            let remoteProducts = try await ProductAPI.getProducts()

            let localProductsDesc = FetchDescriptor<Product>()
            let localProducts = (try? context.fetch(localProductsDesc)) ?? []

            let opDesc = FetchDescriptor<PendingOperation>()
            let allOps = (try? context.fetch(opDesc)) ?? []
            let activeOps = allOps.filter { ($0.state ?? .pending) != .successful }

            // Set of remoteIds that have pending local modifications
            var protectedRemoteIds = Set<Int>()
            for op in activeOps {
                if let rid = op.remoteId {
                    protectedRemoteIds.insert(rid)
                }
                if let prodRemoteId = op.product?.remoteId {
                    protectedRemoteIds.insert(prodRemoteId)
                }
            }

            let remoteIdsSet = Set(remoteProducts.map { $0.productId })

            // 1. Update existing or insert new products
            for dto in remoteProducts {
                // If this product has pending un-synced edits locally, do not overwrite local state
                if protectedRemoteIds.contains(dto.productId) {
                    continue
                }

                if let existing = localProducts.first(where: { $0.remoteId == dto.productId }) {
                    existing.name = dto.name
                    existing.sku = dto.sku
                    existing.stock = dto.stock

                    if let remoteChanges = dto.stockChanges {
                        syncStockHistory(for: existing, remoteChanges: remoteChanges)
                    }
                } else {
                    let newProduct = Product(
                        name: dto.name,
                        sku: dto.sku,
                        stock: dto.stock,
                        remoteId: dto.productId
                    )
                    if let remoteChanges = dto.stockChanges {
                        for sc in remoteChanges {
                            newProduct.stockChanges.append(
                                StockChange(date: sc.date, delta: sc.delta, source: sc.source)
                            )
                        }
                    }
                    context.insert(newProduct)
                }
            }

            // 2. Reconcile remote deletions:
            // If local product has a remoteId, is missing from the remote catalog, and has no pending operations, remove it.
            for local in localProducts {
                guard let rid = local.remoteId else { continue }
                if !remoteIdsSet.contains(rid) && !protectedRemoteIds.contains(rid) {
                    context.delete(local)
                }
            }

            try? context.save()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConstants.Storage.lastSync)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func syncStockHistory(for product: Product, remoteChanges: [StockChangeDTO]) {
        // Clear and reload authoritative history from server
        product.stockChanges.removeAll()
        for change in remoteChanges {
            let item = StockChange(date: change.date, delta: change.delta, source: change.source)
            product.stockChanges.append(item)
        }
    }

    private func isOfflineModeActive() -> Bool {
        return UserDefaults.standard.bool(forKey: AppConstants.Storage.offlineMode)
    }
}
