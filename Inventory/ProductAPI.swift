import Foundation

// MARK: - Data Transfer Objects

public struct StockChangeDTO: Codable, Identifiable {
    public var id: Int { stockChangesId }
    public let stockChangesId: Int
    public let productId: Int
    public let date: Date
    public let delta: Int
    public let source: String
}

public struct ProductDTO: Codable, Identifiable {
    public var id: Int { productId }
    public let productId: Int
    public let name: String
    public let sku: String
    public let stock: Int
    public let stockChanges: [StockChangeDTO]?
}

public struct CreateProductRequest: Codable {
    public let name: String
    public let sku: String
    public let stock: Int

    public init(name: String, sku: String, stock: Int) {
        self.name = name
        self.sku = sku
        self.stock = stock
    }
}

public struct UpdateProductRequest: Codable {
    public let name: String
    public let sku: String
    public let stock: Int

    public init(name: String, sku: String, stock: Int) {
        self.name = name
        self.sku = sku
        self.stock = stock
    }
}

public struct AdjustStockRequest: Codable {
    public let delta: Int
    public let source: String?

    public init(delta: Int, source: String?) {
        self.delta = delta
        self.source = source
    }
}

public struct APIErrorResponse: Codable {
    public let error: String
    public let details: String?
}

// MARK: - API Errors

public enum APIError: LocalizedError, Equatable {
    case badURL
    case serverError(statusCode: Int, message: String)
    case duplicateSku(String)
    case notFound
    case networkUnavailable
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid server URL"
        case .duplicateSku(let msg):
            return msg.isEmpty ? "A product with this SKU already exists." : msg
        case .notFound:
            return "The requested product was not found on the server."
        case .serverError(let code, let msg):
            return msg.isEmpty ? "Server error (HTTP \(code))" : msg
        case .networkUnavailable:
            return "No network connection available."
        case .decodingError(let details):
            return "Failed to parse server response: \(details)"
        }
    }
}

// MARK: - Product API Client

public enum ProductAPI {
    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func baseURL() -> String {
        return "\(AppConstants.API.baseURL)/products"
    }

    private static func handleResponse(data: Data, response: URLResponse, allowedExtra: Int? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 0, message: "Invalid HTTP response")
        }

        if (200...299).contains(http.statusCode) || (allowedExtra != nil && http.statusCode == allowedExtra) {
            return
        }

        var errorMessage = ""
        if let decodedError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            errorMessage = decodedError.error
        } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
            errorMessage = rawString
        }

        if http.statusCode == 409 {
            throw APIError.duplicateSku(errorMessage)
        } else if http.statusCode == 404 {
            throw APIError.notFound
        } else {
            throw APIError.serverError(statusCode: http.statusCode, message: errorMessage)
        }
    }

    public static func getProducts() async throws -> [ProductDTO] {
        guard let url = URL(string: baseURL()) else {
            throw APIError.badURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try handleResponse(data: data, response: response)

        do {
            return try jsonDecoder.decode([ProductDTO].self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    public static func createProduct(_ requestDto: CreateProductRequest) async throws -> ProductDTO {
        guard let url = URL(string: baseURL()) else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(requestDto)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponse(data: data, response: response)

        do {
            return try jsonDecoder.decode(ProductDTO.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    public static func updateProduct(id: Int, _ requestDto: UpdateProductRequest) async throws -> ProductDTO {
        guard let url = URL(string: "\(baseURL())/\(id)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(requestDto)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponse(data: data, response: response)

        do {
            return try jsonDecoder.decode(ProductDTO.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    public static func adjustStock(id: Int, delta: Int, source: String? = nil) async throws -> ProductDTO {
        guard let url = URL(string: "\(baseURL())/\(id)/adjust-stock") else {
            throw APIError.badURL
        }

        let payload = AdjustStockRequest(delta: delta, source: source)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponse(data: data, response: response)

        do {
            return try jsonDecoder.decode(ProductDTO.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    public static func deleteProduct(productId: Int) async throws {
        guard let url = URL(string: "\(baseURL())/\(productId)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)
        try handleResponse(data: data, response: response, allowedExtra: 404)
    }
}
