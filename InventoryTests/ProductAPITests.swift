import Foundation
import XCTest

final class ProductAPITests: XCTestCase {

    func testProductDTODecoding() throws {
        let json = """
        {
            "productId": 101,
            "name": "Mechanical Keyboard",
            "sku": "KB-MEC",
            "stock": 25,
            "stockChanges": [
                {
                    "stockChangesId": 1,
                    "productId": 101,
                    "date": "2026-09-27T12:00:00Z",
                    "delta": 25,
                    "source": "Initial Stock"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ProductDTO.self, from: json)

        XCTAssertEqual(dto.productId, 101)
        XCTAssertEqual(dto.name, "Mechanical Keyboard")
        XCTAssertEqual(dto.sku, "KB-MEC")
        XCTAssertEqual(dto.stock, 25)
        XCTAssertEqual(dto.stockChanges?.count, 1)
        XCTAssertEqual(dto.stockChanges?.first?.delta, 25)
    }

    func testCreateProductRequestEncoding() throws {
        let req = CreateProductRequest(name: "USB-C Hub", sku: "HUB-01", stock: 50)
        let data = try JSONEncoder().encode(req)
        let jsonString = String(data: data, encoding: .utf8)!

        XCTAssertTrue(jsonString.contains("\"name\":\"USB-C Hub\""))
        XCTAssertTrue(jsonString.contains("\"sku\":\"HUB-01\""))
        XCTAssertTrue(jsonString.contains("\"stock\":50"))
    }

    func testAPIErrorLocalization() {
        let duplicateError = APIError.duplicateSku("A product with this SKU already exists.")
        XCTAssertEqual(duplicateError.localizedDescription, "A product with this SKU already exists.")

        let notFoundError = APIError.notFound
        XCTAssertEqual(notFoundError.localizedDescription, "The requested product was not found on the server.")

        let badURLError = APIError.badURL
        XCTAssertEqual(badURLError.localizedDescription, "Invalid server URL")

        let serverError = APIError.serverError(statusCode: 500, message: "Database timeout")
        XCTAssertEqual(serverError.localizedDescription, "Database timeout")
    }
}
