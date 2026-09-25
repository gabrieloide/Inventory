import Foundation
import SwiftData

@Model class Product {
    var name: String
    var sku: String
    var stock: Int
    var remoteId: Int?
    var stockChanges: [StockChange] = []
    @Relationship(deleteRule: .cascade, inverse: \PendingOperation.product) var pendingOperations: [PendingOperation] = []

    init(name: String, sku: String, stock: Int, remoteId: Int? = nil) {
        self.name = name
        self.sku = sku
        self.stock = stock
        self.remoteId = remoteId
    }

}

@Model class StockChange {
    var date: Date
    var delta: Int
    var source: String

    init(date: Date, delta: Int, source: String) {
        self.date = date
        self.delta = delta
        self.source = source
    }
}
struct ProductDTO: Codable {
    let productId: Int
    let name: String
    let sku: String
    let stock: Int
}
enum ProductAPI {
    static func getProducts() async throws -> [ProductDTO] {
        guard let url = URL(string: "http://localhost:5239/products") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let products = try JSONDecoder().decode([ProductDTO].self, from: data)
        return products
    }

    static func createProduct(_ product: ProductDTO) async throws -> ProductDTO {
        guard let url = URL(string: "http://localhost:5239/products") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(product)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let created = try JSONDecoder().decode(ProductDTO.self, from: data)
        return created

    }

    static func updateProduct(_ product: ProductDTO) async throws -> ProductDTO {
        guard let url = URL(string: "http://localhost:5239/products/\(product.productId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(product)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let updated = try JSONDecoder().decode(ProductDTO.self, from: data)
        return updated
    }

    static func deleteProduct(productId: Int) async throws {
        guard let url = URL(string: "http://localhost:5239/products/\(productId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(http.statusCode) || (404 == http.statusCode) else {
            throw URLError(.badServerResponse)
        }

    }

}
