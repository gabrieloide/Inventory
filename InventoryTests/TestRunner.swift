import Foundation
import XCTest

@main
struct TestRunner {
    static func main() {
        print("Running Inventory Test Suite...")
        let suite = XCTestSuite(forTestCaseClass: PendingOperationTests.self)
        let apiSuite = XCTestSuite(forTestCaseClass: ProductAPITests.self)
        suite.addTest(apiSuite)

        let observer = TestProgressObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)

        suite.run()

        if observer.failureCount > 0 {
            print("\nTest Suite Failed: \(observer.failureCount) failures.")
            exit(1)
        } else {
            print("\nTest Suite Passed: \(observer.testCount) tests succeeded.")
            exit(0)
        }
    }
}

final class TestProgressObserver: NSObject, XCTestObservation {
    var testCount = 0
    var failureCount = 0

    func testCaseDidFinish(_ testCase: XCTestCase) {
        testCount += 1
        let status = testCase.testRun?.hasSucceeded == true ? "PASSED" : "FAILED"
        print("  [\(status)] \(testCase.name)")
    }

    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        failureCount += 1
        print("    Failure at line \(lineNumber): \(description)")
    }
}
